// Flat, depth-tagged outline of a pane tree, for structure-viewer UIs
// (ported from the data side of `origami/qml/pane/manager/
// PaneManagerRow.qml`).
//
// The QML original instantiated itself recursively per node. Slint cannot
// nest a component inside itself, so the tree is flattened here instead --
// the same flat-cell-list approach `layout` takes for rendering. A viewer
// draws one row per `OutlineRow`, indented by `depth`.
//
// Rows carry structure only, no display strings: labels like "Tabs (3)" are
// the UI's to format and localize. Which pane is *active* is view state that
// lives outside the tree; a UI compares its own active leaf id against
// `enclosing_leaf_id`.

use crate::pane_tree::PaneNode;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OutlineKind {
    Pane,
    Tabs,
    Drawer,
    Split,
}

#[derive(Debug, Clone, PartialEq)]
pub struct OutlineRow {
    /// Nesting depth, 0 for the root.
    pub depth: usize,
    pub kind: OutlineKind,
    /// The node's own id. `None` only for a `Split` that has none.
    pub node_id: Option<i32>,
    /// The id a drag/drop or activate operation on this row targets: the
    /// nearest enclosing pane/tabs/drawer group for a pane inside a group,
    /// the node's own id for a standalone pane or a group, `None` for a
    /// split (not a valid target itself).
    pub enclosing_leaf_id: Option<i32>,
    /// A pane's title; empty for groups and splits.
    pub title: String,
    /// A pane's view type; empty for groups and splits.
    pub view_type: String,
    /// Number of direct children (0 for a pane).
    pub child_count: usize,
    /// For a split: children are laid out side by side. False otherwise.
    pub horizontal: bool,
    /// For a drawer: whether it is expanded. False otherwise.
    pub expanded: bool,
    /// For a pane directly inside a tabs/drawer group: whether it is that
    /// group's current tab. False otherwise.
    pub is_current_tab: bool,
}

/// Flattens `root` depth-first (parents before children, children in order)
/// into one row per node. `None` (an empty workspace) gives no rows.
pub fn outline(root: Option<&PaneNode>) -> Vec<OutlineRow> {
    let mut rows = Vec::new();
    if let Some(root) = root {
        push_rows(root, 0, None, false, &mut rows);
    }
    rows
}

fn push_rows(
    node: &PaneNode,
    depth: usize,
    group_id: Option<i32>,
    is_current_tab: bool,
    rows: &mut Vec<OutlineRow>,
) {
    match node {
        PaneNode::Pane {
            id,
            title,
            view_type,
            ..
        } => rows.push(OutlineRow {
            depth,
            kind: OutlineKind::Pane,
            node_id: Some(*id),
            enclosing_leaf_id: Some(group_id.unwrap_or(*id)),
            title: title.clone(),
            view_type: view_type.clone(),
            child_count: 0,
            horizontal: false,
            expanded: false,
            is_current_tab,
        }),
        PaneNode::Tabs {
            id,
            children,
            current_index,
        } => {
            rows.push(group_row(
                depth,
                OutlineKind::Tabs,
                *id,
                children.len(),
                false,
            ));
            for (i, child) in children.iter().enumerate() {
                push_rows(&child.node, depth + 1, Some(*id), i == *current_index, rows);
            }
        }
        PaneNode::Drawer {
            id,
            children,
            current_index,
            expanded,
        } => {
            rows.push(group_row(
                depth,
                OutlineKind::Drawer,
                *id,
                children.len(),
                *expanded,
            ));
            for (i, child) in children.iter().enumerate() {
                push_rows(&child.node, depth + 1, Some(*id), i == *current_index, rows);
            }
        }
        PaneNode::Split {
            id,
            orientation,
            children,
        } => {
            rows.push(OutlineRow {
                depth,
                kind: OutlineKind::Split,
                node_id: *id,
                enclosing_leaf_id: None,
                title: String::new(),
                view_type: String::new(),
                child_count: children.len(),
                horizontal: orientation == "horizontal",
                expanded: false,
                is_current_tab: false,
            });
            for child in children {
                push_rows(&child.node, depth + 1, None, false, rows);
            }
        }
    }
}

fn group_row(
    depth: usize,
    kind: OutlineKind,
    id: i32,
    child_count: usize,
    expanded: bool,
) -> OutlineRow {
    OutlineRow {
        depth,
        kind,
        node_id: Some(id),
        enclosing_leaf_id: Some(id),
        title: String::new(),
        view_type: String::new(),
        child_count,
        horizontal: false,
        expanded,
        is_current_tab: false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pane_tree::{GroupChild, SplitChild};
    use serde_json::json;

    fn pane(id: i32, title: &str) -> PaneNode {
        PaneNode::Pane {
            id,
            title: title.to_string(),
            view_type: "text".to_string(),
            props: json!({}),
        }
    }

    #[test]
    fn empty_workspace_has_no_rows() {
        assert!(outline(None).is_empty());
    }

    #[test]
    fn standalone_pane_is_its_own_leaf() {
        let root = pane(1, "Notes");
        let rows = outline(Some(&root));
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].kind, OutlineKind::Pane);
        assert_eq!(rows[0].depth, 0);
        assert_eq!(rows[0].enclosing_leaf_id, Some(1));
        assert_eq!(rows[0].title, "Notes");
        assert!(!rows[0].is_current_tab);
    }

    #[test]
    fn nested_tree_is_depth_first_with_depths_and_leaf_ids() {
        // split(horizontal) -> [ pane 2, tabs 3 -> [pane 4, pane 5 (current)], drawer 6 (open) -> [pane 7] ]
        let root = PaneNode::Split {
            id: Some(1),
            orientation: "horizontal".to_string(),
            children: vec![
                SplitChild {
                    size: 0.3,
                    node: pane(2, "Sidebar"),
                },
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Tabs {
                        id: 3,
                        children: vec![
                            GroupChild { node: pane(4, "A") },
                            GroupChild { node: pane(5, "B") },
                        ],
                        current_index: 1,
                    },
                },
                SplitChild {
                    size: 0.2,
                    node: PaneNode::Drawer {
                        id: 6,
                        children: vec![GroupChild {
                            node: pane(7, "Log"),
                        }],
                        current_index: 0,
                        expanded: true,
                    },
                },
            ],
        };

        let rows = outline(Some(&root));
        let shape: Vec<_> = rows
            .iter()
            .map(|r| (r.depth, r.kind, r.node_id, r.enclosing_leaf_id))
            .collect();
        assert_eq!(
            shape,
            vec![
                (0, OutlineKind::Split, Some(1), None),
                (1, OutlineKind::Pane, Some(2), Some(2)),
                (1, OutlineKind::Tabs, Some(3), Some(3)),
                (2, OutlineKind::Pane, Some(4), Some(3)),
                (2, OutlineKind::Pane, Some(5), Some(3)),
                (1, OutlineKind::Drawer, Some(6), Some(6)),
                (2, OutlineKind::Pane, Some(7), Some(6)),
            ]
        );

        assert!(rows[0].horizontal);
        assert_eq!(rows[0].child_count, 3);
        assert_eq!(rows[2].child_count, 2);
        assert!(!rows[3].is_current_tab);
        assert!(rows[4].is_current_tab);
        assert!(rows[5].expanded);
        assert!(rows[6].is_current_tab);
    }

    #[test]
    fn split_without_id_has_no_node_id() {
        let root = PaneNode::Split {
            id: None,
            orientation: "vertical".to_string(),
            children: vec![SplitChild {
                size: 1.0,
                node: pane(1, "Only"),
            }],
        };
        let rows = outline(Some(&root));
        assert_eq!(rows[0].node_id, None);
        assert!(!rows[0].horizontal);
        assert_eq!(rows[1].depth, 1);
    }
}
