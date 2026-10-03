// Tree edits beyond add/close/move/split: drawer toggle, tabs<->drawer
// conversion, closing a whole group, empty-group pruning, and divider
// resizing. Ported from `origami/qml/pane/core/PaneView.qml`
// (`setDrawerExpanded`, `setGroupType`, `canConvertDrawerToTabs`,
// `closeAllTabs`, `closeGroup`, `setSplitSizes`); each doc comment names its
// counterpart.
//
// Before this module, every consuming app (mumeum, the gallery) carried its
// own copy of these. All are `PaneTree` methods so a caller writes
// `tree.convert_group(id)`.

use crate::pane_tree::{GroupChild, PaneNode, PaneTree, SplitChild};

/// Smallest a split child may get while its divider is dragged, in pixels.
pub const MIN_CHILD_PX_HORIZONTAL: f64 = 80.0;
pub const MIN_CHILD_PX_VERTICAL: f64 = 60.0;

/// A divider drag's starting state, frozen when the drag begins and read
/// (never mutated) on every tick -- see `PaneTree::resize_pair`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct DividerDragBaseline {
    pub split_id: i32,
    /// Index of the child left of (or above) the divider.
    pub left_index: usize,
    /// Size fractions of the two children the divider sits between.
    pub orig_a: f64,
    pub orig_b: f64,
}

impl PaneTree {
    /// Sets a drawer's `expanded` flag (`setDrawerExpanded`). False if
    /// `drawer_id` is not a drawer.
    pub fn set_drawer_expanded(&mut self, drawer_id: i32, value: bool) -> bool {
        match self.root.as_mut().and_then(|r| r.find_node_mut(drawer_id)) {
            Some(PaneNode::Drawer { expanded, .. }) => {
                *expanded = value;
                true
            }
            _ => false,
        }
    }

    /// Flips a drawer's `expanded` flag. False if `drawer_id` is not a
    /// drawer.
    pub fn toggle_drawer_expanded(&mut self, drawer_id: i32) -> bool {
        match self.root.as_ref().and_then(|r| r.find(drawer_id)) {
            Some(PaneNode::Drawer { expanded, .. }) => {
                let next = !*expanded;
                self.set_drawer_expanded(drawer_id, next)
            }
            _ => false,
        }
    }

    /// Whether `group_id` is a drawer whose children are all plain panes --
    /// the only kind that can become a tabs group (`canConvertDrawerToTabs`).
    pub fn can_convert_drawer_to_tabs(&self, group_id: i32) -> bool {
        match self.root.as_ref().and_then(|r| r.find(group_id)) {
            Some(PaneNode::Drawer { children, .. }) => children
                .iter()
                .all(|c| matches!(c.node, PaneNode::Pane { .. })),
            _ => false,
        }
    }

    /// Converts a tabs group to a drawer, or a drawer back to tabs, in
    /// place, keeping id, children and current tab (`setGroupType`). A new
    /// drawer starts expanded. A drawer holding anything but plain panes
    /// cannot become tabs. Returns whether anything changed.
    pub fn convert_group(&mut self, group_id: i32) -> bool {
        let to_tabs = match self.root.as_ref().and_then(|r| r.find(group_id)) {
            Some(PaneNode::Tabs { .. }) => false,
            Some(PaneNode::Drawer { .. }) => {
                if !self.can_convert_drawer_to_tabs(group_id) {
                    return false;
                }
                true
            }
            _ => return false,
        };
        let Some(node) = self.root.as_mut().and_then(|r| r.find_node_mut(group_id)) else {
            return false;
        };
        let (id, children, current_index) = match node {
            PaneNode::Tabs {
                id,
                children,
                current_index,
            }
            | PaneNode::Drawer {
                id,
                children,
                current_index,
                ..
            } => (*id, std::mem::take(children), *current_index),
            _ => return false,
        };
        *node = if to_tabs {
            PaneNode::Tabs {
                id,
                children,
                current_index,
            }
        } else {
            PaneNode::Drawer {
                id,
                children,
                current_index,
                expanded: true,
            }
        };
        true
    }

    /// Removes every tab from a tabs/drawer group but keeps the (now empty)
    /// group itself (`closeAllTabs`). False if `group_id` is not a group.
    pub fn close_all_tabs(&mut self, group_id: i32) -> bool {
        match self.root.as_mut().and_then(|r| r.find_node_mut(group_id)) {
            Some(PaneNode::Tabs {
                children,
                current_index,
                ..
            })
            | Some(PaneNode::Drawer {
                children,
                current_index,
                ..
            }) => {
                children.clear();
                *current_index = 0;
                true
            }
            _ => false,
        }
    }

    /// Removes a group, split or pane together with everything inside it
    /// (`closeGroup`). Closing the root empties the tree. False if the id
    /// is not found.
    pub fn close_group(&mut self, node_id: i32) -> bool {
        if self.root.as_ref().and_then(|r| r.id()) == Some(node_id) {
            self.root = None;
            return true;
        }
        self.remove_standalone(node_id)
    }

    /// Removes tabs/drawer groups left with no children, repeatedly (removing
    /// one can collapse a split and expose another). Groups whose id is in
    /// `keep` are left alone -- an app's permanent, legitimately-empty
    /// group (e.g. an editor area with no file open). This is the "empty
    /// groups are not pruned" gap `README.md` describes; call it after any
    /// mutation that can empty a group (close, drag out, convert).
    /// Returns whether anything was removed.
    pub fn prune_empty_groups(&mut self, keep: &[i32]) -> bool {
        fn find_empty(node: &PaneNode, keep: &[i32]) -> Option<i32> {
            match node {
                PaneNode::Tabs { id, children, .. } | PaneNode::Drawer { id, children, .. }
                    if children.is_empty() && !keep.contains(id) =>
                {
                    Some(*id)
                }
                PaneNode::Split { children, .. } => children
                    .iter()
                    .find_map(|c: &SplitChild| find_empty(&c.node, keep)),
                PaneNode::Tabs { children, .. } | PaneNode::Drawer { children, .. } => children
                    .iter()
                    .find_map(|c: &GroupChild| find_empty(&c.node, keep)),
                PaneNode::Pane { .. } => None,
            }
        }

        let mut pruned = false;
        while let Some(empty_id) = self.root.as_ref().and_then(|r| find_empty(r, keep)) {
            // `remove_standalone` refuses to remove the root; an empty root
            // group has nothing to be pruned out of, so stop.
            if !self.remove_standalone(empty_id) {
                break;
            }
            pruned = true;
        }
        pruned
    }

    /// Captures the baseline for dragging the divider after child
    /// `left_index` of split `split_id`. None if there is no such divider.
    pub fn divider_baseline(
        &self,
        split_id: i32,
        left_index: usize,
    ) -> Option<DividerDragBaseline> {
        match self.root.as_ref()?.find(split_id)? {
            PaneNode::Split { children, .. } if left_index + 1 < children.len() => {
                Some(DividerDragBaseline {
                    split_id,
                    left_index,
                    orig_a: children[left_index].size,
                    orig_b: children[left_index + 1].size,
                })
            }
            _ => None,
        }
    }

    /// Resizes the two children around a dragged divider (`setSplitSizes`).
    /// Sizes are recomputed from `baseline` plus the *total* pointer delta
    /// since the press, not accumulated tick by tick, so a transient
    /// minimum-size clamp does not swallow motion that counts once the
    /// pointer returns to a valid range. `pair_px` is the combined pixel
    /// extent of the two children.
    pub fn resize_pair(
        &mut self,
        baseline: DividerDragBaseline,
        pair_px: f32,
        total_delta_px: f32,
    ) {
        if pair_px <= 0.0 {
            return;
        }
        let DividerDragBaseline {
            split_id,
            left_index,
            orig_a,
            orig_b,
        } = baseline;
        let Some(PaneNode::Split {
            orientation,
            children,
            ..
        }) = self.root.as_mut().and_then(|r| r.find_node_mut(split_id))
        else {
            return;
        };
        if left_index + 1 >= children.len() {
            return;
        }
        let min_child_px = if orientation == "horizontal" {
            MIN_CHILD_PX_HORIZONTAL
        } else {
            MIN_CHILD_PX_VERTICAL
        };
        let pair_px = pair_px as f64;
        let pair_ratio = orig_a + orig_b;
        let delta_ratio = (total_delta_px as f64 / pair_px) * pair_ratio;
        let min = (min_child_px / pair_px) * pair_ratio;
        let mut a = orig_a + delta_ratio;
        let mut b = orig_b - delta_ratio;
        if a < min {
            b -= min - a;
            a = min;
        }
        if b < min {
            a -= min - b;
            b = min;
        }
        children[left_index].size = a.max(0.0);
        children[left_index + 1].size = b.max(0.0);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn pane(id: i32) -> PaneNode {
        PaneNode::Pane {
            id,
            title: format!("p{id}"),
            view_type: "text".into(),
            props: json!({}),
        }
    }

    fn group(id: i32, panes: &[i32]) -> PaneNode {
        PaneNode::Tabs {
            id,
            children: panes
                .iter()
                .map(|&p| GroupChild { node: pane(p) })
                .collect(),
            current_index: 1.min(panes.len().saturating_sub(1)),
        }
    }

    fn split(id: i32, kids: Vec<(f64, PaneNode)>) -> PaneNode {
        PaneNode::Split {
            id: Some(id),
            orientation: "horizontal".into(),
            children: kids
                .into_iter()
                .map(|(size, node)| SplitChild { size, node })
                .collect(),
        }
    }

    #[test]
    fn drawer_toggle_and_set() {
        let mut t = PaneTree::new(Some(PaneNode::Drawer {
            id: 1,
            children: vec![],
            current_index: 0,
            expanded: false,
        }));
        assert!(t.toggle_drawer_expanded(1));
        assert!(matches!(
            t.root,
            Some(PaneNode::Drawer { expanded: true, .. })
        ));
        assert!(t.set_drawer_expanded(1, false));
        assert!(matches!(
            t.root,
            Some(PaneNode::Drawer {
                expanded: false,
                ..
            })
        ));
        assert!(!t.toggle_drawer_expanded(99));
    }

    #[test]
    fn toggle_ignores_non_drawers() {
        let mut t = PaneTree::new(Some(group(1, &[2])));
        assert!(!t.toggle_drawer_expanded(1));
        assert!(!t.set_drawer_expanded(2, true));
    }

    #[test]
    fn convert_round_trips_and_keeps_id_children_and_current_tab() {
        let mut t = PaneTree::new(Some(group(1, &[2, 3])));
        assert!(t.convert_group(1));
        match &t.root {
            Some(PaneNode::Drawer {
                id,
                children,
                current_index,
                expanded,
            }) => {
                assert_eq!((*id, children.len(), *current_index), (1, 2, 1));
                assert!(*expanded, "a new drawer starts expanded");
            }
            other => panic!("expected drawer, got {other:?}"),
        }
        assert!(t.convert_group(1));
        assert!(matches!(
            &t.root,
            Some(PaneNode::Tabs { id: 1, current_index: 1, children, .. }) if children.len() == 2
        ));
    }

    #[test]
    fn drawer_with_a_nested_group_cannot_become_tabs() {
        let mut t = PaneTree::new(Some(PaneNode::Drawer {
            id: 1,
            children: vec![GroupChild {
                node: group(2, &[3]),
            }],
            current_index: 0,
            expanded: true,
        }));
        assert!(!t.can_convert_drawer_to_tabs(1));
        assert!(!t.convert_group(1));
        assert!(matches!(t.root, Some(PaneNode::Drawer { .. })));
    }

    #[test]
    fn convert_ignores_non_groups_and_missing_ids() {
        let mut t = PaneTree::new(Some(split(0, vec![(1.0, pane(1))])));
        assert!(!t.convert_group(1));
        assert!(!t.convert_group(0));
        assert!(!t.convert_group(42));
    }

    #[test]
    fn close_all_tabs_empties_but_keeps_the_group() {
        let mut t = PaneTree::new(Some(split(
            0,
            vec![(0.5, pane(1)), (0.5, group(2, &[3, 4]))],
        )));
        assert!(t.close_all_tabs(2));
        assert!(matches!(
            t.root.as_ref().unwrap().find(2),
            Some(PaneNode::Tabs { children, current_index: 0, .. }) if children.is_empty()
        ));
        assert!(!t.close_all_tabs(1), "a pane is not a group");
    }

    #[test]
    fn close_group_removes_subtree_and_collapses_split() {
        let mut t = PaneTree::new(Some(split(
            0,
            vec![(0.5, pane(1)), (0.5, group(2, &[3, 4]))],
        )));
        assert!(t.close_group(2));
        assert_survivor_is_p1(&t);
        assert!(!t.close_group(2));
    }

    #[test]
    fn close_group_on_root_empties_the_tree() {
        let mut t = PaneTree::new(Some(group(1, &[2])));
        assert!(t.close_group(1));
        assert!(t.root.is_none());
    }

    #[test]
    fn prune_removes_empty_group_and_collapses_its_split() {
        let mut t = PaneTree::new(Some(split(0, vec![(0.5, pane(1)), (0.5, group(2, &[]))])));
        assert!(t.prune_empty_groups(&[]));
        assert_survivor_is_p1(&t);
    }

    #[test]
    fn prune_keeps_listed_groups_and_is_a_noop_when_nothing_is_empty() {
        let mut t = PaneTree::new(Some(split(0, vec![(0.5, pane(1)), (0.5, group(2, &[]))])));
        assert!(!t.prune_empty_groups(&[2]));
        assert!(t.root.as_ref().unwrap().find(2).is_some());

        let mut full = PaneTree::new(Some(group(1, &[2])));
        assert!(!full.prune_empty_groups(&[]));
    }

    #[test]
    fn prune_cascades_through_nested_empty_groups_and_stops_at_an_empty_root() {
        let mut t = PaneTree::new(Some(split(
            0,
            vec![
                (0.5, pane(1)),
                (
                    0.5,
                    split(5, vec![(0.5, group(2, &[])), (0.5, group(3, &[]))]),
                ),
            ],
        )));
        assert!(t.prune_empty_groups(&[]));
        assert_survivor_is_p1(&t);

        let mut lone = PaneTree::new(Some(group(1, &[])));
        assert!(
            !lone.prune_empty_groups(&[]),
            "an empty root has nothing to be pruned from"
        );
        assert!(lone.root.is_some());
    }

    #[test]
    fn find_and_tab_index() {
        let root = split(0, vec![(0.5, pane(1)), (0.5, group(2, &[3, 4]))]);
        assert!(matches!(root.find(4), Some(PaneNode::Pane { id: 4, .. })));
        assert!(root.find(99).is_none());
        assert_eq!(root.tab_index(2, 4), Some(1));
        assert_eq!(root.tab_index(2, 1), None);
        assert_eq!(root.tab_index(1, 1), None, "a pane is not a group");
    }

    /// A split that drops to one child collapses into it and the survivor
    /// takes the split's id (`collapse_into`), so identify it by title.
    fn assert_survivor_is_p1(t: &PaneTree) {
        assert!(
            matches!(&t.root, Some(PaneNode::Pane { title, .. }) if title == "p1"),
            "expected the tree to collapse into pane p1, got {:?}",
            t.root
        );
    }

    fn sizes(t: &PaneTree) -> (f64, f64) {
        match &t.root {
            Some(PaneNode::Split { children, .. }) => (children[0].size, children[1].size),
            _ => panic!("expected split"),
        }
    }

    #[test]
    fn resize_moves_the_divider_by_the_total_delta_from_baseline() {
        let mut t = PaneTree::new(Some(split(0, vec![(0.5, pane(1)), (0.5, pane(2))])));
        let base = t.divider_baseline(0, 0).unwrap();
        t.resize_pair(base, 1000.0, 100.0);
        let (a, b) = sizes(&t);
        assert!((a - 0.6).abs() < 1e-9 && (b - 0.4).abs() < 1e-9);
        // Same baseline, new total delta: recomputed, not accumulated.
        t.resize_pair(base, 1000.0, 50.0);
        let (a, _) = sizes(&t);
        assert!((a - 0.55).abs() < 1e-9);
    }

    #[test]
    fn resize_clamps_to_the_minimum_child_size() {
        let mut t = PaneTree::new(Some(split(0, vec![(0.5, pane(1)), (0.5, pane(2))])));
        let base = t.divider_baseline(0, 0).unwrap();
        t.resize_pair(base, 1000.0, -900.0);
        let (a, b) = sizes(&t);
        let min = MIN_CHILD_PX_HORIZONTAL / 1000.0;
        assert!((a - min).abs() < 1e-9);
        assert!((a + b - 1.0).abs() < 1e-9, "the pair keeps its total");
    }

    #[test]
    fn resize_and_baseline_reject_bad_input() {
        let mut t = PaneTree::new(Some(split(0, vec![(0.5, pane(1)), (0.5, pane(2))])));
        assert!(
            t.divider_baseline(0, 1).is_none(),
            "no divider after the last child"
        );
        assert!(t.divider_baseline(7, 0).is_none());
        let base = t.divider_baseline(0, 0).unwrap();
        t.resize_pair(base, 0.0, 50.0);
        assert_eq!(sizes(&t), (0.5, 0.5));
    }
}
