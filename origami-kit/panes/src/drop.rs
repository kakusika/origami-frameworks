// Edge-zone drop-to-split, ported from origami/qml/pane/core/
// PaneDropOverlay.qml + PaneView.qml's requestDrop/split_pane/split_root
// mutation logic. Extends the existing cross-group tab drag gesture (a
// consumer's own pointer-tracking + drag-ended handling) rather than being
// a separate drag mode -- the only new piece is interpreting *where* the
// same drop point lands (see `compute_zone`) and, based on that, either
// merging into a tabs group (already-existing behavior, generalized here
// to also handle a bare-Pane target), or wrapping the target in a new
// split/drawer.
//
// Not ported from origami: root-drawer-* zones (only reachable when
// dragging a toolbar/drawer as a unit, which no consumer of this crate
// supports dragging yet), and the divider right-click "insert bar/pane at
// this boundary" menu (a separate, non-drag interaction).

use serde_json::json;

use crate::layout::{CellKind, PaneRect, Rect};
use crate::pane_tree::{GroupChild, PaneNode, PaneTree, SplitChild};

// PaneDropOverlay.qml: `rootEdge = 24`, `drawerEdge = 16`; leaf-local
// left/right/top/bottom band width is `min(w,h)*0.28`, capped at 90.
const ROOT_EDGE: f32 = 24.0;
const DRAWER_EDGE: f32 = 16.0;
const MAX_LEAF_EDGE: f32 = 90.0;
const LEAF_EDGE_FRACTION: f32 = 0.28;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DropZone {
    Center,
    Left,
    Right,
    Top,
    Bottom,
    DrawerTop,
    DrawerBottom,
}

/// Returns the drop zone for a point, plus whether it's a root-window-edge
/// zone (which applies at the whole tree's root, ignoring which leaf was
/// actually hovered) rather than a leaf-local one.
pub fn compute_zone(leaf_rect: Rect, viewport_w: f32, viewport_h: f32, x: f32, y: f32) -> (DropZone, bool) {
    if x < ROOT_EDGE {
        return (DropZone::Left, true);
    }
    if x > viewport_w - ROOT_EDGE {
        return (DropZone::Right, true);
    }
    if y < ROOT_EDGE {
        return (DropZone::Top, true);
    }
    if y > viewport_h - ROOT_EDGE {
        return (DropZone::Bottom, true);
    }

    let lx = x - leaf_rect.x;
    let ly = y - leaf_rect.y;
    let edge = (leaf_rect.w.min(leaf_rect.h) * LEAF_EDGE_FRACTION).min(MAX_LEAF_EDGE);

    if lx < edge {
        return (DropZone::Left, false);
    }
    if lx > leaf_rect.w - edge {
        return (DropZone::Right, false);
    }
    if ly < DRAWER_EDGE {
        return (DropZone::DrawerTop, false);
    }
    if ly > leaf_rect.h - DRAWER_EDGE {
        return (DropZone::DrawerBottom, false);
    }
    if ly < edge {
        return (DropZone::Top, false);
    }
    if ly > leaf_rect.h - edge {
        return (DropZone::Bottom, false);
    }
    (DropZone::Center, false)
}

// PaneDropOverlay.qml's own visual: a 6px accent line along the relevant
// edge for any non-center zone, or a translucent fill over the whole leaf
// for `center`.
pub const HIGHLIGHT_LINE_THICKNESS: f32 = 6.0;

/// The rectangle a drop-zone highlight should be drawn at -- a thin strip
/// along the appropriate edge of the leaf (or, for a root-window-edge
/// zone, the whole viewport) for every zone except `Center`, which
/// highlights the entire leaf.
pub fn highlight_rect(zone: DropZone, is_root: bool, leaf_rect: Rect, viewport_w: f32, viewport_h: f32) -> Rect {
    if matches!(zone, DropZone::Center) {
        return leaf_rect;
    }
    let (base, w, h) = if is_root {
        (Rect::new(0.0, 0.0, viewport_w, viewport_h), viewport_w, viewport_h)
    } else {
        (leaf_rect, leaf_rect.w, leaf_rect.h)
    };
    match zone {
        DropZone::Center => unreachable!(),
        DropZone::Left => Rect::new(base.x, base.y, HIGHLIGHT_LINE_THICKNESS, h),
        DropZone::Right => Rect::new(base.x + w - HIGHLIGHT_LINE_THICKNESS, base.y, HIGHLIGHT_LINE_THICKNESS, h),
        DropZone::Top | DropZone::DrawerTop => Rect::new(base.x, base.y, w, HIGHLIGHT_LINE_THICKNESS),
        DropZone::Bottom | DropZone::DrawerBottom => {
            Rect::new(base.x, base.y + h - HIGHLIGHT_LINE_THICKNESS, w, HIGHLIGHT_LINE_THICKNESS)
        }
    }
}

pub fn zone_str(zone: DropZone) -> &'static str {
    match zone {
        DropZone::Center => "center",
        DropZone::Left => "left",
        DropZone::Right => "right",
        DropZone::Top => "top",
        DropZone::Bottom => "bottom",
        DropZone::DrawerTop => "drawer-top",
        DropZone::DrawerBottom => "drawer-bottom",
    }
}

/// Finds the innermost `Leaf` cell containing `(x, y)` -- a Drawer's
/// expanded body can nest another leaf inside its own leaf rect, so the
/// smallest-area match wins rather than the first one found.
pub fn find_target_leaf(rects: &[PaneRect], x: f32, y: f32) -> Option<(i32, Rect)> {
    rects
        .iter()
        .filter(|r| r.kind == CellKind::Leaf && r.rect.contains(x, y))
        .min_by(|a, b| {
            let area_a = a.rect.w * a.rect.h;
            let area_b = b.rect.w * b.rect.h;
            area_a.partial_cmp(&area_b).unwrap_or(std::cmp::Ordering::Equal)
        })
        .map(|r| (r.id, r.rect))
}

// PaneTabBar.qml's own `headerDropArea` (separate from `PaneDropOverlay`,
// and takes priority over it): dropping directly on a group's tab strip
// means "insert at this index" (same-group reorder, or cross-group insert
// at a specific position), not "wrap this leaf in a new split/tabs" --
// without this check first, a drop landing on a tab row would fall
// through to `compute_zone`'s leaf-local `Top` band (the tab strip is
// well within its `min(w,h)*0.28`-capped-at-90px threshold for most pane
// sizes) and wrongly create a split instead.
pub fn find_tab_strip_target(rects: &[PaneRect], x: f32, y: f32) -> Option<(i32, usize)> {
    if let Some(add) = rects.iter().find(|r| r.kind == CellKind::TabAdd && r.rect.contains(x, y)) {
        let count = rects.iter().filter(|r| r.kind == CellKind::TabLabel && r.id == add.id).count();
        return Some((add.id, count));
    }
    rects
        .iter()
        .find(|r| r.kind == CellKind::TabLabel && r.rect.contains(x, y))
        .map(|tab| {
            let midpoint = tab.rect.x + tab.rect.w / 2.0;
            let index = if x < midpoint { tab.index } else { tab.index + 1 };
            (tab.id, index.max(0) as usize)
        })
}

/// A thin vertical insertion-line rect at the boundary `index` sits at
/// within `group_id`'s tab strip -- origami's own "green vertical
/// insertion line" feedback. Reuses the same drop-zone highlight (any
/// zone other than `center`) a consumer already renders for edge-zone
/// drops, which is exactly this line's own look.
pub fn tab_insertion_line_rect(rects: &[PaneRect], group_id: i32, index: usize) -> Option<Rect> {
    let mut labels: Vec<&PaneRect> = rects.iter().filter(|r| r.kind == CellKind::TabLabel && r.id == group_id).collect();
    labels.sort_by_key(|r| r.index);
    let bar = labels.first()?.rect;
    let x = if index == 0 {
        bar.x
    } else if let Some(prev) = labels.get(index - 1) {
        prev.rect.x + prev.rect.w
    } else {
        labels.last().map(|r| r.rect.x + r.rect.w).unwrap_or(bar.x)
    };
    Some(Rect::new(x - 1.5, bar.y, 3.0, bar.h))
}

/// Extracts `source` and inserts it into `target_group_id` at `index`
/// (clamped) -- the tab-strip counterpart to `apply_drop`'s zone-based
/// mutations. For a same-group reorder (`source`'s group equals
/// `target_group_id`), `index` is adjusted down by one when it falls
/// after the dragged item's original position, since extracting it first
/// shifts every later sibling down by one -- without this, dragging
/// rightward within the same strip would always land one slot short of
/// where it visually looked like it was dropped.
pub fn apply_index_drop(tree: &mut PaneTree, source: DragSource, target_group_id: i32, index: usize) -> bool {
    let applied = apply_index_drop_inner(tree, source, target_group_id, index);
    tree.assign_missing_ids();
    applied
}

fn apply_index_drop_inner(tree: &mut PaneTree, source: DragSource, target_group_id: i32, index: usize) -> bool {
    let Some(root) = tree.root.as_mut() else {
        return false;
    };

    let index = match source {
        DragSource::Group { group_id, index: from_index } if group_id == target_group_id && index > from_index => {
            index - 1
        }
        _ => index,
    };

    let dragged = match source {
        DragSource::Group { group_id, index: from_index } => {
            let Some(source_group) = root.find_node_mut(group_id) else {
                return false;
            };
            match extract_child(source_group, from_index) {
                Some(node) => node,
                None => return false,
            }
        }
        DragSource::Standalone { node_id } => match extract_standalone(root, node_id) {
            Some(node) => node,
            None => return false,
        },
    };

    let Some(target) = root.find_node_mut(target_group_id) else {
        // Target vanished mid-drag -- put it back rather than lose it.
        match source {
            DragSource::Group { group_id, index: from_index } => {
                if let Some(source_group) = root.find_node_mut(group_id) {
                    reinsert_child(source_group, from_index, dragged);
                }
            }
            DragSource::Standalone { .. } => {
                let _ = apply_split_root(root, "horizontal", false, dragged);
            }
        }
        return false;
    };
    reinsert_child(target, index, dragged);
    true
}

fn placeholder() -> PaneNode {
    PaneNode::Pane {
        id: -1,
        title: String::new(),
        view_type: String::new(),
        props: json!({}),
    }
}

fn find_node(node: &PaneNode, target_id: i32) -> Option<&PaneNode> {
    if node.id() == Some(target_id) {
        return Some(node);
    }
    match node {
        PaneNode::Split { children, .. } => children.iter().find_map(|c| find_node(&c.node, target_id)),
        PaneNode::Tabs { children, .. } | PaneNode::Drawer { children, .. } => {
            children.iter().find_map(|c| find_node(&c.node, target_id))
        }
        PaneNode::Pane { .. } => None,
    }
}

fn group_child_count(node: &PaneNode) -> usize {
    match node {
        PaneNode::Tabs { children, .. } | PaneNode::Drawer { children, .. } => children.len(),
        _ => usize::MAX,
    }
}

fn extract_child(node: &mut PaneNode, index: usize) -> Option<PaneNode> {
    match node {
        PaneNode::Tabs { children, current_index, .. } | PaneNode::Drawer { children, current_index, .. } => {
            if index >= children.len() {
                return None;
            }
            let child = children.remove(index).node;
            if children.is_empty() {
                *current_index = 0;
            } else if *current_index >= children.len() {
                *current_index = children.len() - 1;
            }
            Some(child)
        }
        _ => None,
    }
}

fn reinsert_child(node: &mut PaneNode, index: usize, child: PaneNode) {
    if let PaneNode::Tabs { children, current_index, .. } | PaneNode::Drawer { children, current_index, .. } = node
    {
        let idx = index.min(children.len());
        children.insert(idx, GroupChild { node: child });
        *current_index = idx;
    }
}

fn renormalize(children: &mut [SplitChild]) {
    let sum: f64 = children.iter().map(|c| c.size).sum();
    if sum > 0.0 {
        for child in children.iter_mut() {
            child.size /= sum;
        }
    }
}

// PaneDropOverlay.qml's "center" effect: append to an existing tabs/drawer
// group, or -- dropping onto a bare pane -- wrap it in a brand new Tabs
// group with the dragged pane appended as the new/last (selected) tab.
fn apply_center(root: &mut PaneNode, target_id: i32, dragged: PaneNode, new_group_id: i32) -> Result<(), PaneNode> {
    let Some(target) = root.find_node_mut(target_id) else {
        return Err(dragged);
    };
    match target {
        PaneNode::Tabs { children, current_index, .. } | PaneNode::Drawer { children, current_index, .. } => {
            children.push(GroupChild { node: dragged });
            *current_index = children.len() - 1;
            Ok(())
        }
        PaneNode::Pane { .. } => {
            let old = std::mem::replace(target, placeholder());
            *target = PaneNode::Tabs {
                id: new_group_id,
                children: vec![GroupChild { node: old }, GroupChild { node: dragged }],
                current_index: 1,
            };
            Ok(())
        }
        PaneNode::Split { .. } => Err(dragged), // unreachable: target is always a leaf id
    }
}

// Same-orientation-merge search, mirroring `pane_tree::split_node_rec` but
// inserting an existing (already-extracted) node rather than constructing
// a fresh pane, and supporting `before` (left/top) vs. after (right/
// bottom) insertion, which the vendored version doesn't need.
fn insert_at_split(node: &mut PaneNode, target_id: i32, orientation: &str, before: bool, slot: &mut Option<PaneNode>) -> bool {
    if node.id() == Some(target_id) {
        let Some(new_node) = slot.take() else {
            return false;
        };
        let old = std::mem::replace(node, placeholder());
        let children = if before {
            vec![SplitChild { size: 0.5, node: new_node }, SplitChild { size: 0.5, node: old }]
        } else {
            vec![SplitChild { size: 0.5, node: old }, SplitChild { size: 0.5, node: new_node }]
        };
        *node = PaneNode::Split {
            id: None,
            orientation: orientation.to_string(),
            children,
        };
        return true;
    }

    match node {
        PaneNode::Split { orientation: split_orientation, children, .. } => {
            if split_orientation == orientation {
                if let Some(idx) = children.iter().position(|c| c.node.id() == Some(target_id)) {
                    let Some(new_node) = slot.take() else {
                        return false;
                    };
                    let half = children[idx].size / 2.0;
                    children[idx].size = half;
                    let insert_idx = if before { idx } else { idx + 1 };
                    children.insert(insert_idx, SplitChild { size: half, node: new_node });
                    return true;
                }
            }
            children.iter_mut().any(|c| insert_at_split(&mut c.node, target_id, orientation, before, slot))
        }
        PaneNode::Tabs { children, .. } | PaneNode::Drawer { children, .. } => {
            children.iter_mut().any(|c| insert_at_split(&mut c.node, target_id, orientation, before, slot))
        }
        PaneNode::Pane { .. } => false,
    }
}

// Root-window-edge zones: mirrors `PaneTree::split_root` but taking an
// already-extracted node. Any existing root (Split of any orientation,
// Tabs, Drawer, or bare Pane) gets wrapped wholesale alongside the dragged
// node 50/50, unless the root is already a same-orientation Split, in
// which case the dragged node just becomes a new sibling at that end.
fn apply_split_root(root: &mut PaneNode, orientation: &str, before: bool, dragged: PaneNode) -> Result<(), PaneNode> {
    let root_node = std::mem::replace(root, placeholder());
    match root_node {
        PaneNode::Split { id, orientation: root_orientation, mut children } if root_orientation == orientation => {
            let insert_idx = if before { 0 } else { children.len() };
            let new_share = 1.0 / (children.len() as f64 + 1.0);
            children.insert(insert_idx, SplitChild { size: new_share, node: dragged });
            renormalize(&mut children);
            *root = PaneNode::Split { id, orientation: root_orientation, children };
            Ok(())
        }
        other => {
            let children = if before {
                vec![SplitChild { size: 0.5, node: dragged }, SplitChild { size: 0.5, node: other }]
            } else {
                vec![SplitChild { size: 0.5, node: other }, SplitChild { size: 0.5, node: dragged }]
            };
            *root = PaneNode::Split {
                id: None,
                orientation: orientation.to_string(),
                children,
            };
            Ok(())
        }
    }
}

fn apply_split(
    root: &mut PaneNode,
    target_id: i32,
    orientation: &str,
    before: bool,
    dragged: PaneNode,
    is_root: bool,
) -> Result<(), PaneNode> {
    if is_root {
        return apply_split_root(root, orientation, before, dragged);
    }
    let mut slot = Some(dragged);
    if insert_at_split(root, target_id, orientation, before, &mut slot) {
        Ok(())
    } else {
        Err(slot.take().unwrap())
    }
}

fn insert_in_drawer(node: &mut PaneNode, target_id: i32, before: bool, new_drawer_id: i32, slot: &mut Option<PaneNode>) -> bool {
    if node.id() == Some(target_id) {
        let Some(new_node) = slot.take() else {
            return false;
        };
        let old = std::mem::replace(node, placeholder());
        let children = if before {
            vec![GroupChild { node: new_node }, GroupChild { node: old }]
        } else {
            vec![GroupChild { node: old }, GroupChild { node: new_node }]
        };
        let current_index = if before { 0 } else { 1 };
        *node = PaneNode::Drawer {
            id: new_drawer_id,
            children,
            current_index,
            expanded: true,
        };
        return true;
    }

    match node {
        PaneNode::Split { children, .. } => {
            children.iter_mut().any(|c| insert_in_drawer(&mut c.node, target_id, before, new_drawer_id, slot))
        }
        PaneNode::Tabs { children, .. } | PaneNode::Drawer { children, .. } => {
            children.iter_mut().any(|c| insert_in_drawer(&mut c.node, target_id, before, new_drawer_id, slot))
        }
        PaneNode::Pane { .. } => false,
    }
}

// drawer-top/bottom: wraps target in a new vertical drawer (expanded),
// dragged pane first (top) or last (bottom).
fn apply_drawer(root: &mut PaneNode, target_id: i32, before: bool, dragged: PaneNode, new_drawer_id: i32) -> Result<(), PaneNode> {
    let mut slot = Some(dragged);
    if insert_in_drawer(root, target_id, before, new_drawer_id, &mut slot) {
        Ok(())
    } else {
        Err(slot.take().unwrap())
    }
}

/// Where a dragged node is being extracted from -- a tab/rail child inside
/// a Tabs/Drawer group (the pre-existing drag gesture), or a node sitting
/// directly as a Split child, dragged as a whole unit via its own grip
/// (`PaneHeader`'s grip for a bare pane, a `DrawerRail`'s grip for an
/// entire Drawer node -- either way, `node_id` names whatever node id is
/// being moved, not necessarily a `Pane`).
#[derive(Debug, Clone, Copy)]
pub enum DragSource {
    Group { group_id: i32, index: usize },
    Standalone { node_id: i32 },
}

// Mirrors `pane_tree::remove_standalone_node`'s search/collapse/
// renormalize shape, but returns the removed node instead of just
// reporting success -- needed here since the whole point is to reinsert it
// elsewhere, whereas `remove_standalone` only ever discards it (a real
// pane close). Never matches `node` itself, only searches its Split/Drawer
// children -- same "never removes the tree's own root" guarantee
// `remove_standalone`'s own doc comment describes.
//
// Deliberately does NOT mirror `remove_standalone_node`'s own
// `collapse_into` id-preservation (which renames the collapsed-into
// survivor to the disappearing Split's old id) -- for a *close*, nothing
// else in the same call is about to look the survivor up by its original
// id, so renaming it is harmless; for a *drag*, `apply_drop`'s caller
// resolves its drop target (which may be exactly this survivor, e.g.
// dragging a Drawer out of a 2-child Split onto its own sibling) by that
// original id in the very same call, after this extraction runs -- a
// rename here would make that lookup fail. Plain-replacing keeps the
// survivor's own id intact.
fn extract_standalone(node: &mut PaneNode, target_id: i32) -> Option<PaneNode> {
    let removable_idx: Option<usize> = match node {
        PaneNode::Split { children, .. } => children.iter().position(|c| c.node.id() == Some(target_id)),
        PaneNode::Drawer { children, .. } => children.iter().position(|c| c.node.id() == Some(target_id)),
        _ => None,
    };

    if let Some(idx) = removable_idx {
        return match node {
            PaneNode::Split { children, .. } => {
                let removed = children.remove(idx).node;
                if children.len() == 1 {
                    *node = children.remove(0).node;
                } else {
                    renormalize(children);
                }
                Some(removed)
            }
            PaneNode::Drawer { children, current_index, .. } => {
                let removed = children.remove(idx).node;
                if *current_index >= children.len() {
                    *current_index = children.len().saturating_sub(1);
                }
                Some(removed)
            }
            _ => unreachable!(),
        };
    }

    match node {
        PaneNode::Split { children, .. } => children.iter_mut().find_map(|c| extract_standalone(&mut c.node, target_id)),
        PaneNode::Tabs { children, .. } => children.iter_mut().find_map(|c| extract_standalone(&mut c.node, target_id)),
        PaneNode::Drawer { children, .. } => children.iter_mut().find_map(|c| extract_standalone(&mut c.node, target_id)),
        PaneNode::Pane { .. } => None,
    }
}

/// Moves the node identified by `source` to `target_leaf_id`, applying
/// `zone`'s effect. Self-drop guards: dropping a group's only child back
/// onto that same group (whichever zone) is a no-op, since removing it
/// would just leave the group empty; dropping a bare pane onto itself is
/// always a no-op. On any other failure to apply (target not found --
/// shouldn't normally happen since `target_leaf_id` comes from
/// `find_target_leaf` against the same tree), the dragged node is
/// reinserted where it came from (or, for a `Standalone` source whose
/// original Split position no longer resolves, wrapped back in at the
/// tree's root) so nothing is silently lost.
pub fn apply_drop(tree: &mut PaneTree, source: DragSource, target_leaf_id: i32, zone: DropZone, is_root: bool) -> bool {
    let applied = apply_drop_inner(tree, source, target_leaf_id, zone, is_root);
    tree.assign_missing_ids();
    applied
}

fn apply_drop_inner(tree: &mut PaneTree, source: DragSource, target_leaf_id: i32, zone: DropZone, is_root: bool) -> bool {
    let new_id = tree.gen_id();

    let Some(root) = tree.root.as_mut() else {
        return false;
    };

    match source {
        DragSource::Group { group_id, .. } if target_leaf_id == group_id => {
            if let Some(group) = find_node(root, group_id) {
                if group_child_count(group) <= 1 {
                    return false;
                }
            }
        }
        DragSource::Standalone { node_id } if target_leaf_id == node_id => return false,
        _ => {}
    }

    let dragged = match source {
        DragSource::Group { group_id, index } => {
            let Some(source_group) = root.find_node_mut(group_id) else {
                return false;
            };
            match extract_child(source_group, index) {
                Some(node) => node,
                None => return false,
            }
        }
        DragSource::Standalone { node_id } => match extract_standalone(root, node_id) {
            Some(node) => node,
            None => return false,
        },
    };

    let result = match zone {
        DropZone::Center => apply_center(root, target_leaf_id, dragged, new_id),
        DropZone::Left => apply_split(root, target_leaf_id, "horizontal", true, dragged, is_root),
        DropZone::Right => apply_split(root, target_leaf_id, "horizontal", false, dragged, is_root),
        DropZone::Top => apply_split(root, target_leaf_id, "vertical", true, dragged, is_root),
        DropZone::Bottom => apply_split(root, target_leaf_id, "vertical", false, dragged, is_root),
        DropZone::DrawerTop => apply_drawer(root, target_leaf_id, true, dragged, new_id),
        DropZone::DrawerBottom => apply_drawer(root, target_leaf_id, false, dragged, new_id),
    };

    match result {
        Ok(()) => true,
        Err(dragged) => {
            match source {
                DragSource::Group { group_id, index } => {
                    if let Some(source_group) = root.find_node_mut(group_id) {
                        reinsert_child(source_group, index, dragged);
                    }
                }
                DragSource::Standalone { .. } => {
                    // Best-effort fallback -- always succeeds regardless of
                    // the current root's shape, at the cost of not
                    // restoring the exact original position. Only reachable
                    // if the resolved target vanished mid-drag.
                    let _ = apply_split_root(root, "horizontal", false, dragged);
                }
            }
            false
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pane(id: i32, view_type: &str) -> PaneNode {
        PaneNode::Pane {
            id,
            title: view_type.to_string(),
            view_type: view_type.to_string(),
            props: json!({}),
        }
    }

    #[test]
    fn zone_leaf_local_edges() {
        let leaf = Rect::new(100.0, 100.0, 200.0, 200.0);
        let (zone, is_root) = compute_zone(leaf, 1000.0, 1000.0, 105.0, 200.0);
        assert_eq!(zone, DropZone::Left);
        assert!(!is_root);

        let (zone, _) = compute_zone(leaf, 1000.0, 1000.0, 295.0, 200.0);
        assert_eq!(zone, DropZone::Right);

        let (zone, _) = compute_zone(leaf, 1000.0, 1000.0, 200.0, 108.0);
        assert_eq!(zone, DropZone::DrawerTop);

        let (zone, _) = compute_zone(leaf, 1000.0, 1000.0, 200.0, 200.0);
        assert_eq!(zone, DropZone::Center);
    }

    #[test]
    fn zone_root_edge_wins_over_leaf_local() {
        let leaf = Rect::new(0.0, 0.0, 50.0, 50.0);
        let (zone, is_root) = compute_zone(leaf, 800.0, 600.0, 10.0, 25.0);
        assert_eq!(zone, DropZone::Left);
        assert!(is_root);
    }

    #[test]
    fn apply_drop_center_wraps_bare_pane_in_new_tabs() {
        let mut tree = PaneTree::new(Some(PaneNode::Split {
            id: Some(0),
            orientation: "horizontal".into(),
            children: vec![
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Tabs {
                        id: 10,
                        current_index: 0,
                        children: vec![
                            GroupChild { node: pane(1, "board") },
                            GroupChild { node: pane(2, "table") },
                        ],
                    },
                },
                SplitChild { size: 0.5, node: pane(3, "calendar") },
            ],
        }));

        assert!(apply_drop(&mut tree, DragSource::Group { group_id: 10, index: 1 }, 3, DropZone::Center, false));

        if let Some(PaneNode::Split { children, .. }) = &tree.root {
            if let PaneNode::Tabs { children: c1, .. } = &children[0].node {
                assert_eq!(c1.len(), 1);
                assert_eq!(c1[0].node.id(), Some(1));
            } else {
                panic!("expected group 10 to remain Tabs");
            }
            if let PaneNode::Tabs { children: c2, current_index, .. } = &children[1].node {
                assert_eq!(c2.len(), 2);
                assert_eq!(c2[0].node.id(), Some(3));
                assert_eq!(c2[1].node.id(), Some(2));
                assert_eq!(*current_index, 1);
            } else {
                panic!("expected pane 3 to have become a Tabs group");
            }
        } else {
            panic!("expected Split root");
        }
    }

    #[test]
    fn apply_drop_left_wraps_target_in_new_split() {
        let mut tree = PaneTree::new(Some(PaneNode::Tabs {
            id: 10,
            current_index: 0,
            children: vec![
                GroupChild { node: pane(1, "board") },
                GroupChild { node: pane(2, "table") },
            ],
        }));

        // No other leaf to drop onto -- drop tab 2 onto its own group's
        // left edge, wrapping the (now single-child) group in a new split.
        assert!(apply_drop(&mut tree, DragSource::Group { group_id: 10, index: 1 }, 10, DropZone::Left, false));

        if let Some(PaneNode::Split { orientation, children, .. }) = &tree.root {
            assert_eq!(orientation, "horizontal");
            assert_eq!(children.len(), 2);
            assert_eq!(children[0].node.id(), Some(2));
            if let PaneNode::Tabs { children: remaining, .. } = &children[1].node {
                assert_eq!(remaining.len(), 1);
                assert_eq!(remaining[0].node.id(), Some(1));
            } else {
                panic!("expected remaining Tabs group as the other split child");
            }
        } else {
            panic!("expected Split root");
        }
    }

    /// Every split id in the tree, in order.
    fn split_ids(node: &PaneNode, out: &mut Vec<Option<i32>>) {
        match node {
            PaneNode::Split { id, children, .. } => {
                out.push(*id);
                children.iter().for_each(|c| split_ids(&c.node, out));
            }
            PaneNode::Tabs { children, .. } | PaneNode::Drawer { children, .. } => {
                children.iter().for_each(|c| split_ids(&c.node, out));
            }
            PaneNode::Pane { .. } => {}
        }
    }

    #[test]
    fn a_split_created_by_a_drop_gets_an_id_so_its_divider_can_be_resized() {
        let mut tree = PaneTree::new(Some(PaneNode::Tabs {
            id: 10,
            current_index: 0,
            children: vec![GroupChild { node: pane(1, "board") }, GroupChild { node: pane(2, "table") }],
        }));
        assert!(apply_drop(&mut tree, DragSource::Group { group_id: 10, index: 1 }, 10, DropZone::Left, false));

        let Some(PaneNode::Split { id: Some(split_id), .. }) = &tree.root else {
            panic!("the new split needs an id, got {:?}", tree.root);
        };
        let split_id = *split_id;
        assert!(tree.divider_baseline(split_id, 0).is_some(), "the divider must be resizable");
    }

    #[test]
    fn nested_splits_created_by_drops_all_have_distinct_ids() {
        // Split(0) [ pane 1, tabs 10 [pane 2, pane 3] ]: drag tab 3 onto the
        // bottom of pane 1, which wraps pane 1 in a new vertical split.
        let mut tree = PaneTree::new(Some(PaneNode::Split {
            id: Some(0),
            orientation: "horizontal".to_string(),
            children: vec![
                SplitChild { size: 0.5, node: pane(1, "board") },
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Tabs {
                        id: 10,
                        current_index: 0,
                        children: vec![GroupChild { node: pane(2, "table") }, GroupChild { node: pane(3, "text") }],
                    },
                },
            ],
        }));
        assert!(apply_drop(&mut tree, DragSource::Group { group_id: 10, index: 1 }, 1, DropZone::Bottom, false));

        let mut ids = Vec::new();
        split_ids(tree.root.as_ref().unwrap(), &mut ids);
        assert_eq!(ids.len(), 2, "expected a nested split, got {ids:?}");
        assert!(ids.iter().all(Option::is_some), "{ids:?}");
        assert_ne!(ids[0], ids[1], "split ids must be distinct: {ids:?}");
        for id in ids.into_iter().flatten() {
            assert!(tree.divider_baseline(id, 0).is_some(), "split {id} must be resizable");
        }
    }

    #[test]
    fn apply_drop_root_edge_wraps_whole_tree() {
        let mut tree = PaneTree::new(Some(PaneNode::Split {
            id: Some(0),
            orientation: "horizontal".into(),
            children: vec![
                SplitChild {
                    size: 1.0,
                    node: PaneNode::Tabs {
                        id: 10,
                        current_index: 0,
                        children: vec![
                            GroupChild { node: pane(1, "board") },
                            GroupChild { node: pane(2, "table") },
                        ],
                    },
                },
            ],
        }));

        assert!(apply_drop(&mut tree, DragSource::Group { group_id: 10, index: 0 }, 10, DropZone::Bottom, true));

        if let Some(PaneNode::Split { orientation, children, .. }) = &tree.root {
            assert_eq!(orientation, "vertical");
            assert_eq!(children.len(), 2);
            assert_eq!(children[1].node.id(), Some(1));
        } else {
            panic!("expected a new vertical Split at the root");
        }
    }

    #[test]
    fn apply_drop_drawer_zone_wraps_in_new_drawer() {
        let mut tree = PaneTree::new(Some(PaneNode::Tabs {
            id: 10,
            current_index: 0,
            children: vec![
                GroupChild { node: pane(1, "board") },
                GroupChild { node: pane(2, "table") },
            ],
        }));

        assert!(apply_drop(&mut tree, DragSource::Group { group_id: 10, index: 0 }, 10, DropZone::DrawerTop, false));

        if let Some(PaneNode::Drawer { children, expanded, current_index, .. }) = &tree.root {
            assert!(expanded);
            assert_eq!(*current_index, 0);
            assert_eq!(children[0].node.id(), Some(1));
        } else {
            panic!("expected a new Drawer root");
        }
    }

    #[test]
    fn apply_drop_self_drop_on_sole_child_is_noop() {
        let mut tree = PaneTree::new(Some(PaneNode::Tabs {
            id: 10,
            current_index: 0,
            children: vec![GroupChild { node: pane(1, "board") }],
        }));

        assert!(!apply_drop(&mut tree, DragSource::Group { group_id: 10, index: 0 }, 10, DropZone::Left, false));
        if let Some(PaneNode::Tabs { children, .. }) = &tree.root {
            assert_eq!(children.len(), 1);
        } else {
            panic!("tree should be unchanged");
        }
    }

    #[test]
    fn apply_drop_standalone_drags_a_whole_drawer_not_just_a_pane() {
        // `DragSource::Standalone`/`extract_standalone` work on any node
        // type sitting directly as a Split child, not only bare Panes --
        // this exercises dragging an entire (collapsed) Drawer via its
        // own rail grip.
        let mut tree = PaneTree::new(Some(PaneNode::Split {
            id: Some(0),
            orientation: "horizontal".into(),
            children: vec![
                SplitChild {
                    size: 0.3,
                    node: PaneNode::Drawer {
                        id: 10,
                        current_index: 0,
                        expanded: false,
                        children: vec![GroupChild { node: pane(1, "table") }],
                    },
                },
                SplitChild { size: 0.7, node: pane(2, "board") },
            ],
        }));

        assert!(apply_drop(
            &mut tree,
            DragSource::Standalone { node_id: 10 },
            2,
            DropZone::Center,
            false
        ));

        if let Some(PaneNode::Tabs { children, .. }) = &tree.root {
            // The whole Drawer (still containing pane 1) moved into a new
            // Tabs group alongside pane 2, not just its contents unwrapped.
            assert_eq!(children.len(), 2);
            assert_eq!(children[0].node.id(), Some(2));
            match &children[1].node {
                PaneNode::Drawer { id, children: drawer_children, .. } => {
                    assert_eq!(*id, 10);
                    assert_eq!(drawer_children.len(), 1);
                    assert_eq!(drawer_children[0].node.id(), Some(1));
                }
                other => panic!("expected the dragged Drawer node intact, got {other:?}"),
            }
        } else {
            panic!("expected Split root to have become Tabs (bare pane 2 wrapped by center-drop)");
        }
    }

    // Three tabs in group 10, each 60px wide starting at x=0, y=0..30, plus
    // a 30px-wide TabAdd cell right after them -- a minimal stand-in for
    // what `layout_tabs` actually produces.
    fn test_rect(id: i32, rect: Rect, index: i32, kind: CellKind) -> PaneRect {
        PaneRect {
            id,
            child_id: 0,
            index,
            extra: 0.0,
            rect,
            z: 2,
            kind,
            view_type: String::new(),
            title: String::new(),
            active: false,
        }
    }

    fn tab_strip_rects(group_id: i32, count: i32) -> Vec<PaneRect> {
        let mut rects: Vec<PaneRect> = (0..count)
            .map(|i| test_rect(group_id, Rect::new(i as f32 * 60.0, 0.0, 60.0, 30.0), i, CellKind::TabLabel))
            .collect();
        rects.push(test_rect(group_id, Rect::new(count as f32 * 60.0, 0.0, 30.0, 30.0), 0, CellKind::TabAdd));
        rects
    }

    #[test]
    fn tab_strip_target_picks_side_by_midpoint() {
        let rects = tab_strip_rects(10, 3);
        // Left half of tab index 1 (x in [60,90)) -> insert before it (index 1).
        assert_eq!(find_tab_strip_target(&rects, 70.0, 15.0), Some((10, 1)));
        // Right half of tab index 1 (x in [90,120)) -> insert after it (index 2).
        assert_eq!(find_tab_strip_target(&rects, 110.0, 15.0), Some((10, 2)));
        // On the TabAdd cell -> append at the end.
        assert_eq!(find_tab_strip_target(&rects, 190.0, 15.0), Some((10, 3)));
        // Below the strip entirely -> no tab-strip target.
        assert_eq!(find_tab_strip_target(&rects, 70.0, 100.0), None);
    }

    #[test]
    fn tab_insertion_line_tracks_index() {
        let rects = tab_strip_rects(10, 3);
        assert_eq!(tab_insertion_line_rect(&rects, 10, 0).unwrap().x, -1.5);
        assert_eq!(tab_insertion_line_rect(&rects, 10, 2).unwrap().x, 118.5);
        assert_eq!(tab_insertion_line_rect(&rects, 10, 3).unwrap().x, 178.5);
    }

    #[test]
    fn apply_index_drop_reorders_within_same_group_adjusting_for_shift() {
        let mut tree = PaneTree::new(Some(PaneNode::Tabs {
            id: 10,
            current_index: 0,
            children: vec![
                GroupChild { node: pane(1, "board") },
                GroupChild { node: pane(2, "calendar") },
                GroupChild { node: pane(3, "table") },
            ],
        }));

        // Drag pane 1 (index 0) to land after pane 3 (raw target index 3,
        // computed as if pane 1 were still in place) -- should end up
        // last, not second-to-last, once the -1 shift adjustment applies.
        assert!(apply_index_drop(
            &mut tree,
            DragSource::Group { group_id: 10, index: 0 },
            10,
            3
        ));

        if let Some(PaneNode::Tabs { children, .. }) = &tree.root {
            let ids: Vec<_> = children.iter().map(|c| c.node.id()).collect();
            assert_eq!(ids, vec![Some(2), Some(3), Some(1)]);
        } else {
            panic!("expected Tabs root");
        }
    }

    #[test]
    fn apply_index_drop_inserts_across_groups_at_position() {
        let mut tree = PaneTree::new(Some(PaneNode::Split {
            id: Some(0),
            orientation: "horizontal".into(),
            children: vec![
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Tabs {
                        id: 10,
                        current_index: 0,
                        children: vec![GroupChild { node: pane(1, "board") }],
                    },
                },
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Tabs {
                        id: 20,
                        current_index: 0,
                        children: vec![
                            GroupChild { node: pane(2, "calendar") },
                            GroupChild { node: pane(3, "table") },
                        ],
                    },
                },
            ],
        }));

        // Move pane 1 from group 10 into group 20 at index 1 (between the
        // two existing tabs), not just appended at the end.
        assert!(apply_index_drop(
            &mut tree,
            DragSource::Group { group_id: 10, index: 0 },
            20,
            1
        ));

        if let Some(PaneNode::Split { children, .. }) = &tree.root {
            if let PaneNode::Tabs { children: c1, .. } = &children[0].node {
                assert!(c1.is_empty());
            } else {
                panic!("expected group 10 to remain Tabs (now empty)");
            }
            if let PaneNode::Tabs { children: c2, .. } = &children[1].node {
                let ids: Vec<_> = c2.iter().map(|c| c.node.id()).collect();
                assert_eq!(ids, vec![Some(2), Some(1), Some(3)]);
            } else {
                panic!("expected group 20 Tabs");
            }
        } else {
            panic!("expected Split root");
        }
    }
}
