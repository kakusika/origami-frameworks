use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitChild {
    pub size: f64,
    pub node: PaneNode,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupChild {
    pub node: PaneNode,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum PaneNode {
    Split {
        #[serde(default)]
        id: Option<i32>,
        orientation: String,
        children: Vec<SplitChild>,
    },
    Tabs {
        id: i32,
        children: Vec<GroupChild>,
        #[serde(default, rename = "currentIndex")]
        current_index: usize,
    },
    Drawer {
        id: i32,
        children: Vec<GroupChild>,
        #[serde(default, rename = "currentIndex")]
        current_index: usize,
        #[serde(default)]
        expanded: bool,
    },
    Pane {
        id: i32,
        title: String,
        #[serde(rename = "viewType")]
        view_type: String,
        #[serde(default = "default_props")]
        props: Value,
    },
}

fn default_props() -> Value {
    json!({})
}

impl PaneNode {
    pub fn id(&self) -> Option<i32> {
        match self {
            PaneNode::Split { id, .. } => *id,
            PaneNode::Tabs { id, .. } => Some(*id),
            PaneNode::Drawer { id, .. } => Some(*id),
            PaneNode::Pane { id, .. } => Some(*id),
        }
    }

    pub fn is_group(&self) -> bool {
        matches!(self, PaneNode::Tabs { .. } | PaneNode::Drawer { .. })
    }

    /// Recursively max ID in the tree
    pub fn max_id(&self) -> i32 {
        let current = self.id().unwrap_or(0);
        let child_max = match self {
            PaneNode::Split { children, .. } => {
                children.iter().map(|c| c.node.max_id()).max().unwrap_or(0)
            }
            PaneNode::Tabs { children, .. } | PaneNode::Drawer { children, .. } => {
                children.iter().map(|c| c.node.max_id()).max().unwrap_or(0)
            }
            PaneNode::Pane { .. } => 0,
        };
        current.max(child_max)
    }

    /// Finds a node by ID (mutable reference)
    pub fn find_node_mut(&mut self, target_id: i32) -> Option<&mut PaneNode> {
        if self.id() == Some(target_id) {
            return Some(self);
        }
        match self {
            PaneNode::Split { children, .. } => {
                for child in children {
                    if let Some(found) = child.node.find_node_mut(target_id) {
                        return Some(found);
                    }
                }
            }
            PaneNode::Tabs { children, .. } | PaneNode::Drawer { children, .. } => {
                for child in children {
                    if let Some(found) = child.node.find_node_mut(target_id) {
                        return Some(found);
                    }
                }
            }
            PaneNode::Pane { .. } => {}
        }
        None
    }
}

pub struct PaneTree {
    pub root: Option<PaneNode>,
    next_id: i32,
}

impl PaneTree {
    pub fn new(root: Option<PaneNode>) -> Self {
        let max_id = root.as_ref().map(|r| r.max_id()).unwrap_or(0);
        Self {
            root,
            next_id: max_id + 1,
        }
    }

    pub fn gen_id(&mut self) -> i32 {
        let id = self.next_id;
        self.next_id += 1;
        id
    }

    pub fn serialize_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string_pretty(&self.root)
    }

    pub fn from_json(json_str: &str) -> Result<Self, serde_json::Error> {
        let root: Option<PaneNode> = serde_json::from_str(json_str)?;
        Ok(Self::new(root))
    }

    /// Change view_type and title of a target pane
    pub fn change_pane_type(&mut self, pane_id: i32, new_type: &str, new_title: &str) -> bool {
        if let Some(root) = &mut self.root {
            if let Some(node) = root.find_node_mut(pane_id) {
                if let PaneNode::Pane {
                    title, view_type, ..
                } = node
                {
                    *title = new_title.to_string();
                    *view_type = new_type.to_string();
                    return true;
                }
            }
        }
        false
    }

    /// Add a new tab to an existing group
    pub fn add_tab(&mut self, group_id: i32, view_type: &str, title: &str) -> Option<i32> {
        let new_id = self.gen_id();
        let new_pane = PaneNode::Pane {
            id: new_id,
            title: title.to_string(),
            view_type: view_type.to_string(),
            props: json!({}),
        };

        if let Some(root) = &mut self.root {
            if let Some(group) = root.find_node_mut(group_id) {
                match group {
                    PaneNode::Tabs {
                        children,
                        current_index,
                        ..
                    }
                    | PaneNode::Drawer {
                        children,
                        current_index,
                        ..
                    } => {
                        children.push(GroupChild { node: new_pane });
                        *current_index = children.len() - 1;
                        return Some(new_id);
                    }
                    _ => {}
                }
            }
        }
        None
    }

    /// Set active tab index for a group
    pub fn set_current_tab(&mut self, group_id: i32, index: usize) -> bool {
        if let Some(root) = &mut self.root {
            if let Some(group) = root.find_node_mut(group_id) {
                match group {
                    PaneNode::Tabs {
                        children,
                        current_index,
                        ..
                    }
                    | PaneNode::Drawer {
                        children,
                        current_index,
                        ..
                    } => {
                        if index < children.len() {
                            *current_index = index;
                            return true;
                        }
                    }
                    _ => {}
                }
            }
        }
        false
    }

    /// Close a tab by ID in a group
    pub fn close_tab(&mut self, group_id: i32, tab_id: i32) -> bool {
        if let Some(root) = &mut self.root {
            if let Some(group) = root.find_node_mut(group_id) {
                match group {
                    PaneNode::Tabs {
                        children,
                        current_index,
                        ..
                    }
                    | PaneNode::Drawer {
                        children,
                        current_index,
                        ..
                    } => {
                        if let Some(idx) = children.iter().position(|c| c.node.id() == Some(tab_id))
                        {
                            children.remove(idx);
                            if children.is_empty() {
                                *current_index = 0;
                            } else if *current_index >= children.len() {
                                *current_index = children.len() - 1;
                            }
                            return true;
                        }
                    }
                    _ => {}
                }
            }
        }
        false
    }

    /// Split a node (Pane, Tabs, Drawer, Split) by target_id, replacing it with a Split node
    /// containing the target node and a newly created Pane node.
    ///
    /// If the target's immediate parent is already a Split with the same
    /// orientation, the new pane is inserted as a direct sibling there
    /// instead -- otherwise this would nest a redundant same-orientation
    /// Split one level deeper (e.g. a horizontal Split directly containing
    /// another horizontal Split).
    pub fn split_pane(
        &mut self,
        target_id: i32,
        orientation: &str,
        new_view_type: &str,
        new_title: &str,
    ) -> Option<i32> {
        let new_id = self.gen_id();
        let new_pane = PaneNode::Pane {
            id: new_id,
            title: new_title.to_string(),
            view_type: new_view_type.to_string(),
            props: json!({}),
        };

        if let Some(root) = &mut self.root {
            if split_node_rec(root, target_id, orientation, new_pane) {
                return Some(new_id);
            }
        }
        None
    }

    /// Split the root node with a new pane, placing the new pane at the root
    /// boundary specified by `orientation` and `first` (true = first/left/top, false = last/right/bottom).
    pub fn split_root(
        &mut self,
        orientation: &str,
        first: bool,
        new_view_type: &str,
        new_title: &str,
    ) -> Option<i32> {
        let new_id = self.gen_id();
        let new_pane = PaneNode::Pane {
            id: new_id,
            title: new_title.to_string(),
            view_type: new_view_type.to_string(),
            props: json!({}),
        };

        if let Some(root_node) = self.root.take() {
            if let PaneNode::Split {
                id,
                orientation: root_orientation,
                mut children,
            } = root_node
            {
                if root_orientation == orientation {
                    let insert_idx = if first { 0 } else { children.len() };
                    let new_share = 1.0 / (children.len() as f64 + 1.0);
                    children.insert(
                        insert_idx,
                        SplitChild {
                            size: new_share,
                            node: new_pane,
                        },
                    );
                    renormalize_sizes(&mut children);
                    self.root = Some(PaneNode::Split {
                        id,
                        orientation: root_orientation,
                        children,
                    });
                    return Some(new_id);
                } else {
                    let old_split = PaneNode::Split {
                        id,
                        orientation: root_orientation,
                        children,
                    };
                    let children = if first {
                        vec![
                            SplitChild {
                                size: 0.5,
                                node: new_pane,
                            },
                            SplitChild {
                                size: 0.5,
                                node: old_split,
                            },
                        ]
                    } else {
                        vec![
                            SplitChild {
                                size: 0.5,
                                node: old_split,
                            },
                            SplitChild {
                                size: 0.5,
                                node: new_pane,
                            },
                        ]
                    };
                    self.root = Some(PaneNode::Split {
                        id: None,
                        orientation: orientation.to_string(),
                        children,
                    });
                    return Some(new_id);
                }
            } else {
                let children = if first {
                    vec![
                        SplitChild {
                            size: 0.5,
                            node: new_pane,
                        },
                        SplitChild {
                            size: 0.5,
                            node: root_node,
                        },
                    ]
                } else {
                    vec![
                        SplitChild {
                            size: 0.5,
                            node: root_node,
                        },
                        SplitChild {
                            size: 0.5,
                            node: new_pane,
                        },
                    ]
                };
                self.root = Some(PaneNode::Split {
                    id: None,
                    orientation: orientation.to_string(),
                    children,
                });
                return Some(new_id);
            }
        }
        None
    }

    /// Move a tab from `from_group_id` at `from_index` to `to_group_id` at `to_index`.
    pub fn move_tab(
        &mut self,
        from_group_id: i32,
        from_index: usize,
        to_group_id: i32,
        to_index: usize,
    ) -> bool {
        if self.root.is_none() {
            return false;
        }

        let extracted_child = {
            let root = self.root.as_mut().unwrap();
            let from_group = match root.find_node_mut(from_group_id) {
                Some(g) => g,
                None => return false,
            };

            match from_group {
                PaneNode::Tabs {
                    children,
                    current_index,
                    ..
                }
                | PaneNode::Drawer {
                    children,
                    current_index,
                    ..
                } => {
                    if from_index >= children.len() {
                        return false;
                    }
                    let child = children.remove(from_index);
                    if children.is_empty() {
                        *current_index = 0;
                    } else if *current_index >= children.len() {
                        *current_index = children.len() - 1;
                    }
                    child
                }
                _ => return false,
            }
        };

        let root = self.root.as_mut().unwrap();
        let to_group = match root.find_node_mut(to_group_id) {
            Some(g) => g,
            None => {
                if let Some(src) = root.find_node_mut(from_group_id) {
                    match src {
                        PaneNode::Tabs {
                            children,
                            current_index,
                            ..
                        }
                        | PaneNode::Drawer {
                            children,
                            current_index,
                            ..
                        } => {
                            let idx = from_index.min(children.len());
                            children.insert(idx, extracted_child);
                            *current_index = idx;
                        }
                        _ => {}
                    }
                }
                return false;
            }
        };

        match to_group {
            PaneNode::Tabs {
                children,
                current_index,
                ..
            }
            | PaneNode::Drawer {
                children,
                current_index,
                ..
            } => {
                let insert_idx = to_index.min(children.len());
                children.insert(insert_idx, extracted_child);
                *current_index = insert_idx;
                true
            }
            _ => false,
        }
    }

    /// Removes the standalone pane/split/tabs/drawer node identified by
    /// `target_id` from wherever it sits as a direct child of a "split" or
    /// "drawer" in the tree. See `remove_standalone_node` for the
    /// recursive walk/collapse/renormalize behavior. Returns false (a
    /// no-op) if `target_id` is the tree's own root -- same as
    /// PaneView.qml, removing the whole tree's root is the caller's own
    /// responsibility (e.g. closeTab()'s `root.tree = null` branch), not
    /// something this shared primitive decides on its own.
    pub fn remove_standalone(&mut self, target_id: i32) -> bool {
        match &mut self.root {
            Some(root) => remove_standalone_node(root, target_id),
            None => false,
        }
    }
}

/// Rescales `children`'s size fractions back up to sum to 1. Needed after
/// removing a child from a split's children so the survivors' fractions
/// don't leave a blank gap the width of the removed child's old share --
/// mirrors PaneView.qml's `_renormalizeSizes()`.
fn renormalize_sizes(children: &mut [SplitChild]) {
    let sum: f64 = children.iter().map(|c| c.size).sum();
    if sum <= 0.0 {
        return;
    }
    for child in children.iter_mut() {
        child.size /= sum;
    }
}

/// Overwrites `container` in place with `remaining`'s content, keeping
/// `container`'s own id where `remaining`'s node kind has one -- mirrors
/// PaneView.qml's `_collapseInto()`. Used when a "split" drops to a single
/// remaining child, which then takes the collapsing split's place.
fn collapse_into(container: &mut PaneNode, remaining: PaneNode) {
    let kept_id = container.id();
    *container = remaining;
    match container {
        PaneNode::Split { id, .. } => *id = kept_id,
        PaneNode::Tabs { id, .. } | PaneNode::Drawer { id, .. } | PaneNode::Pane { id, .. } => {
            if let Some(kept_id) = kept_id {
                *id = kept_id;
            }
        }
    }
}

/// Removes the standalone child node identified by `target_id` from
/// whichever "split" or "drawer" directly holds it, anywhere under `node`.
/// A "split" that drops to one remaining child collapses into it (see
/// `collapse_into`) and otherwise renormalizes its size fractions; a
/// "drawer" never collapses (mirrors `PaneNode::is_group`) and just keeps
/// its `current_index` in range. Mirrors PaneView.qml's
/// `_removeStandalonePane()`. Returns true if `target_id` was found and
/// removed.
pub fn remove_standalone_node(node: &mut PaneNode, target_id: i32) -> bool {
    let removable_idx: Option<usize> = match node {
        PaneNode::Split { children, .. } => {
            children.iter().position(|c| c.node.id() == Some(target_id))
        }
        PaneNode::Drawer { children, .. } => {
            children.iter().position(|c| c.node.id() == Some(target_id))
        }
        _ => None,
    };

    if let Some(idx) = removable_idx {
        match node {
            PaneNode::Split { children, .. } => {
                children.remove(idx);
                if children.len() == 1 {
                    let remaining = children.remove(0).node;
                    collapse_into(node, remaining);
                } else {
                    renormalize_sizes(children);
                }
            }
            PaneNode::Drawer {
                children,
                current_index,
                ..
            } => {
                children.remove(idx);
                if *current_index >= children.len() {
                    *current_index = children.len().saturating_sub(1);
                }
            }
            _ => unreachable!(),
        }
        return true;
    }

    match node {
        PaneNode::Split { children, .. } => {
            for child in children.iter_mut() {
                if remove_standalone_node(&mut child.node, target_id) {
                    return true;
                }
            }
            false
        }
        PaneNode::Tabs { children, .. } => {
            for child in children.iter_mut() {
                if remove_standalone_node(&mut child.node, target_id) {
                    return true;
                }
            }
            false
        }
        PaneNode::Drawer { children, .. } => {
            for child in children.iter_mut() {
                if remove_standalone_node(&mut child.node, target_id) {
                    return true;
                }
            }
            false
        }
        PaneNode::Pane { .. } => false,
    }
}

fn split_node_rec(
    node: &mut PaneNode,
    target_id: i32,
    orientation: &str,
    new_pane: PaneNode,
) -> bool {
    if node.id() == Some(target_id) {
        let old_node = std::mem::replace(
            node,
            PaneNode::Pane {
                id: -1,
                title: String::new(),
                view_type: String::new(),
                props: json!({}),
            },
        );
        *node = PaneNode::Split {
            id: None,
            orientation: orientation.to_string(),
            children: vec![
                SplitChild {
                    size: 0.5,
                    node: old_node,
                },
                SplitChild {
                    size: 0.5,
                    node: new_pane,
                },
            ],
        };
        return true;
    }

    match node {
        PaneNode::Split {
            orientation: split_orientation,
            children,
            ..
        } => {
            if split_orientation == orientation {
                if let Some(idx) = children.iter().position(|c| c.node.id() == Some(target_id)) {
                    let half = children[idx].size / 2.0;
                    children[idx].size = half;
                    children.insert(
                        idx + 1,
                        SplitChild {
                            size: half,
                            node: new_pane,
                        },
                    );
                    return true;
                }
            }
            for child in children {
                if split_node_rec(&mut child.node, target_id, orientation, new_pane.clone()) {
                    return true;
                }
            }
        }
        PaneNode::Tabs { children, .. } | PaneNode::Drawer { children, .. } => {
            for child in children {
                if split_node_rec(&mut child.node, target_id, orientation, new_pane.clone()) {
                    return true;
                }
            }
        }
        PaneNode::Pane { .. } => {}
    }

    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tree_serialization() {
        let tree = PaneTree::new(Some(PaneNode::Tabs {
            id: 1,
            current_index: 0,
            children: vec![GroupChild {
                node: PaneNode::Pane {
                    id: 2,
                    title: "Explorer".to_string(),
                    view_type: "explorer".to_string(),
                    props: json!({}),
                },
            }],
        }));

        let json_str = tree.serialize_json().unwrap();
        assert!(json_str.contains("\"type\": \"tabs\""));
        assert!(json_str.contains("\"viewType\": \"explorer\""));

        let restored = PaneTree::from_json(&json_str).unwrap();
        assert_eq!(tree.root, restored.root);
    }

    #[test]
    fn test_add_and_close_tab() {
        let mut tree = PaneTree::new(Some(PaneNode::Tabs {
            id: 1,
            current_index: 0,
            children: vec![GroupChild {
                node: PaneNode::Pane {
                    id: 2,
                    title: "Initial Pane".to_string(),
                    view_type: "board".to_string(),
                    props: json!({}),
                },
            }],
        }));

        let new_id = tree.add_tab(1, "calendar", "Calendar").unwrap();
        assert_eq!(new_id, 3);

        if let Some(PaneNode::Tabs {
            children,
            current_index,
            ..
        }) = &tree.root
        {
            assert_eq!(children.len(), 2);
            assert_eq!(*current_index, 1);
        } else {
            panic!("Expected Tabs node");
        }

        assert!(tree.close_tab(1, new_id));
        if let Some(PaneNode::Tabs {
            children,
            current_index,
            ..
        }) = &tree.root
        {
            assert_eq!(children.len(), 1);
            assert_eq!(*current_index, 0);
        } else {
            panic!("Expected Tabs node");
        }
    }

    #[test]
    fn test_split_pane() {
        let mut tree = PaneTree::new(Some(PaneNode::Pane {
            id: 1,
            title: "Board".to_string(),
            view_type: "board".to_string(),
            props: json!({}),
        }));

        let new_id = tree
            .split_pane(1, "horizontal", "calendar", "Calendar")
            .unwrap();
        assert_eq!(new_id, 2);

        if let Some(PaneNode::Split {
            orientation,
            children,
            ..
        }) = &tree.root
        {
            assert_eq!(orientation, "horizontal");
            assert_eq!(children.len(), 2);
            assert_eq!(children[0].node.id(), Some(1));
            assert_eq!(children[1].node.id(), Some(2));
        } else {
            panic!("Expected Split root");
        }
    }

    #[test]
    fn test_split_pane_merges_into_same_orientation_parent() {
        let mut tree = PaneTree::new(Some(PaneNode::Split {
            id: None,
            orientation: "horizontal".to_string(),
            children: vec![
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Pane {
                        id: 1,
                        title: "A".to_string(),
                        view_type: "board".to_string(),
                        props: json!({}),
                    },
                },
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Pane {
                        id: 2,
                        title: "B".to_string(),
                        view_type: "board".to_string(),
                        props: json!({}),
                    },
                },
            ],
        }));

        let new_id = tree
            .split_pane(1, "horizontal", "calendar", "Calendar")
            .unwrap();

        if let Some(PaneNode::Split {
            orientation,
            children,
            ..
        }) = &tree.root
        {
            // No nested Split -- the new pane lands as a third sibling of
            // the existing horizontal Split, not wrapped around pane 1.
            assert_eq!(orientation, "horizontal");
            assert_eq!(children.len(), 3);
            assert_eq!(children[0].node.id(), Some(1));
            assert_eq!(children[1].node.id(), Some(new_id));
            assert_eq!(children[2].node.id(), Some(2));
            assert!((children[0].size - 0.25).abs() < 1e-9);
            assert!((children[1].size - 0.25).abs() < 1e-9);
            assert!((children[2].size - 0.5).abs() < 1e-9);
        } else {
            panic!("Expected Split root");
        }
    }

    #[test]
    fn test_split_pane_nests_different_orientation() {
        let mut tree = PaneTree::new(Some(PaneNode::Split {
            id: None,
            orientation: "horizontal".to_string(),
            children: vec![SplitChild {
                size: 1.0,
                node: PaneNode::Pane {
                    id: 1,
                    title: "A".to_string(),
                    view_type: "board".to_string(),
                    props: json!({}),
                },
            }],
        }));

        let new_id = tree
            .split_pane(1, "vertical", "calendar", "Calendar")
            .unwrap();

        if let Some(PaneNode::Split { children, .. }) = &tree.root {
            assert_eq!(children.len(), 1);
            if let PaneNode::Split {
                orientation,
                children: inner,
                ..
            } = &children[0].node
            {
                assert_eq!(orientation, "vertical");
                assert_eq!(inner.len(), 2);
                assert_eq!(inner[0].node.id(), Some(1));
                assert_eq!(inner[1].node.id(), Some(new_id));
            } else {
                panic!("Expected nested vertical Split");
            }
        } else {
            panic!("Expected Split root");
        }
    }

    #[test]
    fn test_move_tab() {
        let mut tree = PaneTree::new(Some(PaneNode::Split {
            id: None,
            orientation: "horizontal".to_string(),
            children: vec![
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Tabs {
                        id: 10,
                        current_index: 0,
                        children: vec![
                            GroupChild {
                                node: PaneNode::Pane {
                                    id: 1,
                                    title: "Tab 1".to_string(),
                                    view_type: "board".to_string(),
                                    props: json!({}),
                                },
                            },
                            GroupChild {
                                node: PaneNode::Pane {
                                    id: 2,
                                    title: "Tab 2".to_string(),
                                    view_type: "calendar".to_string(),
                                    props: json!({}),
                                },
                            },
                        ],
                    },
                },
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Tabs {
                        id: 20,
                        current_index: 0,
                        children: vec![GroupChild {
                            node: PaneNode::Pane {
                                id: 3,
                                title: "Tab 3".to_string(),
                                view_type: "table".to_string(),
                                props: json!({}),
                            },
                        }],
                    },
                },
            ],
        }));

        // Move Tab 2 (index 1 in group 10) to group 20 at index 1
        assert!(tree.move_tab(10, 1, 20, 1));

        if let Some(PaneNode::Split { children, .. }) = &tree.root {
            if let PaneNode::Tabs { children: c1, .. } = &children[0].node {
                assert_eq!(c1.len(), 1);
                assert_eq!(c1[0].node.id(), Some(1));
            } else {
                panic!("Expected group 10 Tabs");
            }

            if let PaneNode::Tabs { children: c2, .. } = &children[1].node {
                assert_eq!(c2.len(), 2);
                assert_eq!(c2[0].node.id(), Some(3));
                assert_eq!(c2[1].node.id(), Some(2));
            } else {
                panic!("Expected group 20 Tabs");
            }
        }
    }

    #[test]
    fn test_remove_standalone_collapses_split_to_one_child() {
        let mut tree = PaneTree::new(Some(PaneNode::Split {
            id: None,
            orientation: "horizontal".to_string(),
            children: vec![
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Pane {
                        id: 1,
                        title: "A".to_string(),
                        view_type: "board".to_string(),
                        props: json!({}),
                    },
                },
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Pane {
                        id: 2,
                        title: "B".to_string(),
                        view_type: "board".to_string(),
                        props: json!({}),
                    },
                },
            ],
        }));

        assert!(tree.remove_standalone(1));

        // The split (which had a None id) collapses into pane 2 in place.
        if let Some(PaneNode::Pane { id, title, .. }) = &tree.root {
            assert_eq!(*id, 2);
            assert_eq!(title, "B");
        } else {
            panic!("Expected root to collapse into remaining Pane");
        }
    }

    #[test]
    fn test_remove_standalone_renormalizes_split_sizes() {
        let mut tree = PaneTree::new(Some(PaneNode::Split {
            id: None,
            orientation: "horizontal".to_string(),
            children: vec![
                SplitChild {
                    size: 0.25,
                    node: PaneNode::Pane {
                        id: 1,
                        title: "A".to_string(),
                        view_type: "board".to_string(),
                        props: json!({}),
                    },
                },
                SplitChild {
                    size: 0.25,
                    node: PaneNode::Pane {
                        id: 2,
                        title: "B".to_string(),
                        view_type: "board".to_string(),
                        props: json!({}),
                    },
                },
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Pane {
                        id: 3,
                        title: "C".to_string(),
                        view_type: "board".to_string(),
                        props: json!({}),
                    },
                },
            ],
        }));

        assert!(tree.remove_standalone(1));

        if let Some(PaneNode::Split { children, .. }) = &tree.root {
            assert_eq!(children.len(), 2);
            assert_eq!(children[0].node.id(), Some(2));
            assert_eq!(children[1].node.id(), Some(3));
            // Remaining shares (0.25, 0.5) renormalized back up to sum to 1.
            assert!((children[0].size - 1.0 / 3.0).abs() < 1e-9);
            assert!((children[1].size - 2.0 / 3.0).abs() < 1e-9);
        } else {
            panic!("Expected Split root");
        }
    }

    #[test]
    fn test_remove_standalone_from_drawer_never_collapses() {
        let mut tree = PaneTree::new(Some(PaneNode::Drawer {
            id: 10,
            current_index: 1,
            expanded: true,
            children: vec![
                GroupChild {
                    node: PaneNode::Pane {
                        id: 1,
                        title: "A".to_string(),
                        view_type: "board".to_string(),
                        props: json!({}),
                    },
                },
                GroupChild {
                    node: PaneNode::Pane {
                        id: 2,
                        title: "B".to_string(),
                        view_type: "board".to_string(),
                        props: json!({}),
                    },
                },
            ],
        }));

        // Removing the currently-active (index 1) child clamps
        // current_index back into range instead of collapsing the drawer.
        assert!(tree.remove_standalone(2));

        if let Some(PaneNode::Drawer {
            children,
            current_index,
            ..
        }) = &tree.root
        {
            assert_eq!(children.len(), 1);
            assert_eq!(children[0].node.id(), Some(1));
            assert_eq!(*current_index, 0);
        } else {
            panic!("Expected Drawer root to remain a Drawer");
        }
    }

    #[test]
    fn test_remove_standalone_recurses_and_reports_missing() {
        let mut tree = PaneTree::new(Some(PaneNode::Split {
            id: None,
            orientation: "horizontal".to_string(),
            children: vec![
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Split {
                        id: None,
                        orientation: "vertical".to_string(),
                        children: vec![
                            SplitChild {
                                size: 0.5,
                                node: PaneNode::Pane {
                                    id: 1,
                                    title: "A".to_string(),
                                    view_type: "board".to_string(),
                                    props: json!({}),
                                },
                            },
                            SplitChild {
                                size: 0.5,
                                node: PaneNode::Pane {
                                    id: 2,
                                    title: "B".to_string(),
                                    view_type: "board".to_string(),
                                    props: json!({}),
                                },
                            },
                        ],
                    },
                },
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Pane {
                        id: 3,
                        title: "C".to_string(),
                        view_type: "board".to_string(),
                        props: json!({}),
                    },
                },
            ],
        }));

        assert!(tree.remove_standalone(1));
        if let Some(PaneNode::Split { children, .. }) = &tree.root {
            // Nested vertical split collapsed into pane 2 in place.
            assert_eq!(children[0].node.id(), Some(2));
            assert_eq!(children[1].node.id(), Some(3));
        } else {
            panic!("Expected Split root");
        }

        assert!(!tree.remove_standalone(999));
    }

    #[test]
    fn test_split_root() {
        let mut tree = PaneTree::new(Some(PaneNode::Pane {
            id: 1,
            title: "Board".to_string(),
            view_type: "board".to_string(),
            props: json!({}),
        }));

        let new_id = tree
            .split_root("horizontal", true, "calendar", "Calendar")
            .unwrap();
        assert_eq!(new_id, 2);

        if let Some(PaneNode::Split {
            orientation,
            children,
            ..
        }) = &tree.root
        {
            assert_eq!(orientation, "horizontal");
            assert_eq!(children.len(), 2);
            assert_eq!(children[0].node.id(), Some(2));
            assert_eq!(children[1].node.id(), Some(1));
        } else {
            panic!("Expected Split root");
        }
    }
}
