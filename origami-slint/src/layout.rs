// Flattens a `pane_tree::PaneNode` tree into a flat list of absolute
// on-screen rectangles, replacing what origami's QML does declaratively
// and recursively via nested Loader-dispatched components
// (qml/pane/groups/PaneSplit.qml, PaneDrawer.qml, qml/pane/core/
// PaneNode.qml). A Slint consumer's `for` loop renders this flat list
// directly -- there is no recursive component nesting on the Slint side,
// which sidesteps both of Slint's current gaps for this use case: it
// doesn't support recursive/self-referencing components, and it can't
// reparent a live component instance to a new position in the tree the way
// QML's `PaneView.materialize()` does.
//
// Formulas below are ported from the real QML sources (cited per
// function) rather than re-derived. One deliberate simplification: the
// real app's base unit (`gridUnit`) is derived from live font metrics x a
// user scale setting (ayame's `Units` singleton); callers instead pass in
// whatever `LayoutMetrics` they've resolved (`DEFAULT_GRID_UNIT` is only a
// placeholder default for callers with no such resolution of their own).
//
// `id`/`child_id`/`index`/`extra` are reused across cell kinds rather than
// growing a field per interaction, mirroring how little state each
// interaction actually needs:
//   - Content:    id = pane id.
//   - TabLabel:   id = owning group id, child_id = this tab's pane id,
//                 index = this tab's position in the group (for
//                 set_current_tab/move_tab).
//   - TabAdd:     id = owning group id.
//   - DrawerRail: id = owning drawer id.
//   - Divider:    id = owning split id (-1 if the split has no id, which
//                 disables drag-resize for it -- see `layout_split`),
//                 index = the left/top neighbor's index in the split,
//                 extra = the combined effective px size of that
//                 neighbor pair at this layout pass (needed to convert a
//                 drag's pixel delta back into a `size` ratio delta).

use crate::pane_tree::{GroupChild, PaneNode, SplitChild};

pub const DEFAULT_GRID_UNIT: f32 = 20.0;

#[derive(Debug, Clone, Copy)]
pub struct LayoutMetrics {
    pub grid_unit: f32,
}

impl LayoutMetrics {
    pub fn new(grid_unit: f32) -> Self {
        Self { grid_unit }
    }

    pub fn small_spacing(&self) -> f32 {
        (self.grid_unit / 4.0).floor().max(2.0)
    }

    pub fn large_spacing(&self) -> f32 {
        self.small_spacing() * 2.0
    }

    pub fn group_content_margin(&self) -> f32 {
        (self.small_spacing() / 2.0).floor().max(1.0)
    }

    // PaneDrawer.qml: `railSize: StyleKit.Units.collapsedDrawerSize`, and
    // `Units.qml`: `collapsedDrawerSize = gridUnit * 1.8`.
    pub fn collapsed_drawer_size(&self) -> f32 {
        self.grid_unit * 1.8
    }

    // PaneTabBar.qml: `height: StyleKit.Units.gridUnit * 1.6`.
    pub fn tab_bar_height(&self) -> f32 {
        self.grid_unit * 1.6
    }

    // PaneHeader.qml doesn't specify its own fixed height in the research
    // pass's findings -- reusing tab_bar_height matches the precedent
    // already established for PaneMaximizeBar ("same height as the tab
    // strip row, so no chrome jump").
    pub fn header_height(&self) -> f32 {
        self.tab_bar_height()
    }
}

impl Default for LayoutMetrics {
    fn default() -> Self {
        Self::new(DEFAULT_GRID_UNIT)
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Rect {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
}

impl Rect {
    pub fn new(x: f32, y: f32, w: f32, h: f32) -> Self {
        Self { x, y, w, h }
    }

    pub fn contains(&self, px: f32, py: f32) -> bool {
        px >= self.x && px <= self.x + self.w && py >= self.y && py <= self.y + self.h
    }

    fn inset(&self, left: f32, top: f32, right: f32, bottom: f32) -> Rect {
        Rect {
            x: self.x + left,
            y: self.y + top,
            w: (self.w - left - right).max(0.0),
            h: (self.h - top - bottom).max(0.0),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CellKind {
    Content,
    TabLabel,
    TabAdd,
    DrawerRail,
    Divider,
    GroupFrame,
    // Not rendered by a plain flat cell loop (no "leaf" kind branch, so it
    // paints as an invisible positioned rect if a consumer iterates blindly)
    // -- one per Tabs/Drawer/bare-Pane node, `rect` = that node's *full*
    // allocated area (tab strip + body, or the whole rect for a bare pane),
    // used only for edge-zone drop-to-split hit-testing in `drop.rs`.
    // Mirrors origami's `PaneDropOverlay` being sized to the whole
    // `PaneLeaf`, not just its body.
    Leaf,
    // PaneHeader.qml's chrome row: grip + title, present above content on
    // every leaf (below the tab strip for Tabs/Drawer, or directly at the
    // top for a bare Pane -- there's no tab strip to sit under). `id` =
    // the leaf's currently-draggable pane (the active child for a group,
    // or the pane itself if bare), `child_id` = the owning group's id, or
    // -1 for a bare pane (a drag handler uses this to distinguish
    // `drop::DragSource::Group` from `::Standalone`), `index` = that
    // pane's position within the owning group (unused/0 if bare),
    // `active` = whether this leaf is the focused one (renders the accent
    // line).
    Header,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PaneRect {
    pub id: i32,
    pub child_id: i32,
    pub index: i32,
    pub extra: f32,
    pub rect: Rect,
    pub z: i32,
    pub kind: CellKind,
    pub view_type: String, // only meaningful for CellKind::Content
    pub title: String,     // tab label / drawer rail label / pane title
    pub active: bool,       // TabLabel: is current tab; DrawerRail: is expanded
}

impl PaneRect {
    fn new(id: i32, rect: Rect, z: i32, kind: CellKind) -> Self {
        Self {
            id,
            child_id: 0,
            index: 0,
            extra: 0.0,
            rect,
            z,
            kind,
            view_type: String::new(),
            title: String::new(),
            active: false,
        }
    }
}

// origami's `PaneView._displayNode = maximizedArea || tree`: swaps what
// gets rendered to point directly at one leaf's own node, hiding every
// sibling/the split structure it actually lives in -- the tree itself is
// never mutated, so un-maximizing (clearing `maximized_leaf_id`) needs no
// undo logic. Falls back to `root` if the id no longer resolves (the
// maximized leaf's own pane having been closed out from under it, say) --
// callers should also proactively clear their own stored id in that case.
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

pub fn layout_tree(
    root: &PaneNode,
    viewport: Rect,
    metrics: &LayoutMetrics,
    active_leaf_id: Option<i32>,
    maximized_leaf_id: Option<i32>,
) -> Vec<PaneRect> {
    let mut out = Vec::new();
    let display_root = maximized_leaf_id.and_then(|id| find_node(root, id)).unwrap_or(root);
    layout_node(display_root, viewport, metrics, None, active_leaf_id, false, &mut out);
    out
}

// `is_group_content` is true only when laying out a Tabs/Drawer's *active
// child* -- that slot's chrome (Leaf + PaneHeader) is already provided by
// the enclosing group itself (see `layout_tabs`/`layout_drawer`), so a
// bare Pane found there must NOT push its own on top (that produced a
// literal duplicate Header cell before this flag existed -- caught by
// `tabs_header_tracks_active_child_and_owning_group`'s own header-count
// assertion). Split/Tabs/Drawer children are always genuine independent
// leaves regardless of this flag -- only the bare-`Pane` case cares.
#[allow(clippy::too_many_arguments)]
fn layout_node(
    node: &PaneNode,
    rect: Rect,
    metrics: &LayoutMetrics,
    parent_split_orientation: Option<&str>,
    active_leaf_id: Option<i32>,
    is_group_content: bool,
    out: &mut Vec<PaneRect>,
) {
    match node {
        PaneNode::Split {
            id,
            orientation,
            children,
        } => layout_split(*id, orientation, children, rect, metrics, active_leaf_id, out),
        PaneNode::Tabs {
            id,
            children,
            current_index,
        } => layout_tabs(*id, children, *current_index, rect, metrics, active_leaf_id, out),
        PaneNode::Drawer {
            id,
            children,
            current_index,
            expanded,
        } => layout_drawer(
            *id,
            children,
            *current_index,
            *expanded,
            rect,
            metrics,
            parent_split_orientation,
            active_leaf_id,
            out,
        ),
        PaneNode::Pane {
            id,
            title,
            view_type,
            ..
        } => {
            let content_rect = if is_group_content {
                rect
            } else {
                out.push(PaneRect::new(*id, rect, 0, CellKind::Leaf));

                let header_h = metrics.header_height().min(rect.h);
                let mut header = PaneRect::new(*id, Rect::new(rect.x, rect.y, rect.w, header_h), 1, CellKind::Header);
                header.child_id = -1; // no owning group -- a bare standalone pane
                header.title = title.clone();
                header.active = active_leaf_id == Some(*id);
                out.push(header);

                Rect::new(rect.x, rect.y + header_h, rect.w, (rect.h - header_h).max(0.0))
            };

            let mut r = PaneRect::new(*id, content_rect, 0, CellKind::Content);
            r.view_type = view_type.clone();
            r.title = title.clone();
            r.active = true;
            out.push(r);
        }
    }
}

// PaneDrawer.qml: `fixedSizePx: expanded ? 0 : railSize` -- the only
// producer of a nonzero fixedSizePx here (PaneToolbar's fixed thickness is
// out of scope: no toolbar node kind is ported here).
fn fixed_size_px(node: &PaneNode, metrics: &LayoutMetrics) -> f32 {
    match node {
        PaneNode::Drawer { expanded: false, .. } => metrics.collapsed_drawer_size(),
        _ => 0.0,
    }
}

// PaneSplit.qml's `effectiveSizes`: fixed children get their own px; the
// remainder is split among proportional children by their `size` ratio,
// normalized against each other (not against the full 1.0 budget, which
// may include fixed children's now-irrelevant shares).
fn effective_sizes(children: &[SplitChild], fixed: &[f32], total: f32) -> Vec<f32> {
    let fixed_total: f32 = fixed.iter().sum();
    let remaining = (total - fixed_total).max(0.0);
    let expanded_sum: f64 = children
        .iter()
        .zip(fixed)
        .filter(|(_, f)| **f == 0.0)
        .map(|(c, _)| c.size)
        .sum();
    let expanded_count = children
        .iter()
        .zip(fixed)
        .filter(|(_, f)| **f == 0.0)
        .count()
        .max(1);

    children
        .iter()
        .zip(fixed)
        .map(|(c, f)| {
            if *f > 0.0 {
                *f
            } else if expanded_sum > 0.0 {
                ((c.size / expanded_sum) as f32) * remaining
            } else {
                remaining / expanded_count as f32
            }
        })
        .collect()
}

fn layout_split(
    split_id: Option<i32>,
    orientation: &str,
    children: &[SplitChild],
    rect: Rect,
    metrics: &LayoutMetrics,
    active_leaf_id: Option<i32>,
    out: &mut Vec<PaneRect>,
) {
    let horizontal = orientation == "horizontal";
    let total = if horizontal { rect.w } else { rect.h };
    let fixed: Vec<f32> = children
        .iter()
        .map(|c| fixed_size_px(&c.node, metrics))
        .collect();
    let sizes = effective_sizes(children, &fixed, total);

    let mut offset = 0.0f32;
    for (child, size) in children.iter().zip(&sizes) {
        let child_rect = if horizontal {
            Rect::new(rect.x + offset, rect.y, *size, rect.h)
        } else {
            Rect::new(rect.x, rect.y + offset, rect.w, *size)
        };
        layout_node(&child.node, child_rect, metrics, Some(orientation), active_leaf_id, false, out);
        offset += size;
    }

    // Drag-resizable divider lines at each boundary. A split with no id
    // (e.g. one created ad hoc and never assigned one) still renders its
    // divider but with id=-1, which the resize-divider handler treats as
    // "not resizable" (find_node_mut(-1) never matches a real node).
    let mut offset = 0.0f32;
    for i in 0..sizes.len().saturating_sub(1) {
        offset += sizes[i];
        let pair_px = sizes[i] + sizes[i + 1];
        let d = if horizontal {
            Rect::new(rect.x + offset - 0.5, rect.y, 1.0, rect.h)
        } else {
            Rect::new(rect.x, rect.y + offset - 0.5, rect.w, 1.0)
        };
        let mut r = PaneRect::new(split_id.unwrap_or(-1), d, 1, CellKind::Divider);
        r.index = i as i32;
        r.extra = pair_px;
        out.push(r);
    }
}

fn pane_title(node: &PaneNode) -> String {
    match node {
        PaneNode::Pane { title, .. } => title.clone(),
        PaneNode::Tabs { .. } => "Tabs".into(),
        PaneNode::Drawer { .. } => "Drawer".into(),
        PaneNode::Split { .. } => "Split".into(),
    }
}

// PaneLeaf.qml/PaneTabBar.qml: a fixed-height tab strip above a body
// showing only `current_index`'s child. Framing (border+radius+margin)
// applies to Tabs/Drawer, not Split/Pane (PaneNode.qml's exclusion rule);
// margin is 0 on top since the tab strip already provides the gap. A
// fixed-width "add tab" button sits at the strip's right end (not part of
// the real PaneTabBar.qml, an addition for interactive consumers).
#[allow(clippy::too_many_arguments)]
fn layout_tabs(
    id: i32,
    children: &[GroupChild],
    current_index: usize,
    rect: Rect,
    metrics: &LayoutMetrics,
    active_leaf_id: Option<i32>,
    out: &mut Vec<PaneRect>,
) {
    out.push(PaneRect::new(id, rect, 0, CellKind::Leaf));

    let bar_h = metrics.tab_bar_height();
    let add_w = bar_h;
    let labels_w = (rect.w - add_w).max(0.0);
    let n = children.len().max(1);
    let tab_w = labels_w / n as f32;
    for (i, child) in children.iter().enumerate() {
        let r_rect = Rect::new(rect.x + tab_w * i as f32, rect.y, tab_w, bar_h);
        let mut r = PaneRect::new(id, r_rect, 2, CellKind::TabLabel);
        r.child_id = child.node.id().unwrap_or(-1);
        r.index = i as i32;
        r.title = pane_title(&child.node);
        r.active = i == current_index;
        out.push(r);
    }
    let add_rect = Rect::new(rect.x + labels_w, rect.y, add_w, bar_h);
    out.push(PaneRect::new(id, add_rect, 2, CellKind::TabAdd));

    let margin = metrics.group_content_margin();
    let raw_body = Rect::new(rect.x, rect.y + bar_h, rect.w, (rect.h - bar_h).max(0.0));
    out.push(PaneRect::new(id, raw_body, 0, CellKind::GroupFrame));
    let body = raw_body.inset(margin, 0.0, margin, margin);

    // PaneHeader.qml: a chrome row below the tab strip, for the *active*
    // tab's own pane (the grip here drags that specific pane out, same as
    // origami -- dragging a different, inactive tab is still done via its
    // own TabLabel, unaffected by this).
    let header_h = metrics.header_height().min(body.h);
    if let Some(current) = children.get(current_index) {
        let mut header = PaneRect::new(
            current.node.id().unwrap_or(-1),
            Rect::new(body.x, body.y, body.w, header_h),
            1,
            CellKind::Header,
        );
        header.child_id = id;
        header.index = current_index as i32;
        header.title = pane_title(&current.node);
        header.active = active_leaf_id == Some(id);
        out.push(header);

        let content_body = Rect::new(body.x, body.y + header_h, body.w, (body.h - header_h).max(0.0));
        layout_node(&current.node, content_body, metrics, None, active_leaf_id, true, out);
    }
}

// PaneDrawer.qml: fixed "rail" always shows; body only when expanded.
// Rail orientation is forced perpendicular to a direct parent Split's
// orientation (a horizontal split gets a vertical/left-edge rail, a
// vertical split gets a horizontal/top-edge rail); with no parent split
// context, default to the vertical/left-edge rail. The floating overlay
// case (an expanded drawer that isn't inline in a split) is a non-goal
// here -- only the inline collapsed/expanded rail case is implemented.
// Clicking the rail toggles `expanded` (left to the consumer's own
// toggle-drawer handler).
#[allow(clippy::too_many_arguments)]
fn layout_drawer(
    id: i32,
    children: &[GroupChild],
    current_index: usize,
    expanded: bool,
    rect: Rect,
    metrics: &LayoutMetrics,
    parent_split_orientation: Option<&str>,
    active_leaf_id: Option<i32>,
    out: &mut Vec<PaneRect>,
) {
    out.push(PaneRect::new(id, rect, 0, CellKind::Leaf));

    let rail = metrics.collapsed_drawer_size();
    let rail_is_row = parent_split_orientation == Some("vertical");
    let rail_rect = if rail_is_row {
        Rect::new(rect.x, rect.y, rect.w, rail)
    } else {
        Rect::new(rect.x, rect.y, rail, rect.h)
    };
    let title = children
        .get(current_index)
        .map(|c| pane_title(&c.node))
        .unwrap_or_default();
    let mut rail_cell = PaneRect::new(id, rail_rect, 2, CellKind::DrawerRail);
    rail_cell.title = title;
    rail_cell.active = expanded;
    out.push(rail_cell);

    if expanded {
        let raw_body = if rail_is_row {
            Rect::new(rect.x, rect.y + rail, rect.w, (rect.h - rail).max(0.0))
        } else {
            Rect::new(rect.x + rail, rect.y, (rect.w - rail).max(0.0), rect.h)
        };
        let margin = metrics.group_content_margin();
        out.push(PaneRect::new(id, raw_body, 0, CellKind::GroupFrame));
        let body = raw_body.inset(margin, margin, margin, margin);

        let header_h = metrics.header_height().min(body.h);
        if let Some(current) = children.get(current_index) {
            let mut header = PaneRect::new(
                current.node.id().unwrap_or(-1),
                Rect::new(body.x, body.y, body.w, header_h),
                1,
                CellKind::Header,
            );
            header.child_id = id;
            header.index = current_index as i32;
            header.title = pane_title(&current.node);
            header.active = active_leaf_id == Some(id);
            out.push(header);

            let content_body = Rect::new(body.x, body.y + header_h, body.w, (body.h - header_h).max(0.0));
            layout_node(&current.node, content_body, metrics, None, active_leaf_id, true, out);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn metrics_derive_from_grid_unit() {
        let m = LayoutMetrics::new(20.0);
        assert_eq!(m.small_spacing(), 5.0);
        assert_eq!(m.large_spacing(), 10.0);
        assert_eq!(m.group_content_margin(), 2.0);
        assert_eq!(m.collapsed_drawer_size(), 36.0);
        assert_eq!(m.tab_bar_height(), 32.0);
    }

    fn pane(id: i32, view_type: &str) -> PaneNode {
        PaneNode::Pane {
            id,
            title: view_type.to_string(),
            view_type: view_type.to_string(),
            props: json!({}),
        }
    }

    #[test]
    fn horizontal_split_50_50() {
        let tree = PaneNode::Split {
            id: Some(9),
            orientation: "horizontal".into(),
            children: vec![
                SplitChild {
                    size: 0.5,
                    node: pane(1, "board"),
                },
                SplitChild {
                    size: 0.5,
                    node: pane(2, "table"),
                },
            ],
        };
        let rects = layout_tree(&tree, Rect::new(0.0, 0.0, 200.0, 100.0), &LayoutMetrics::default(), None, None);

        let content: Vec<_> = rects.iter().filter(|r| r.kind == CellKind::Content).collect();
        assert_eq!(content.len(), 2);
        // Below each bare pane's own 32px PaneHeader row (see
        // `metrics.header_height()`).
        assert_eq!(content[0].rect, Rect::new(0.0, 32.0, 100.0, 68.0));
        assert_eq!(content[1].rect, Rect::new(100.0, 32.0, 100.0, 68.0));

        let dividers: Vec<_> = rects.iter().filter(|r| r.kind == CellKind::Divider).collect();
        assert_eq!(dividers.len(), 1);
        assert!((dividers[0].rect.x - 99.5).abs() < 1e-6);
        assert_eq!(dividers[0].id, 9);
        assert_eq!(dividers[0].index, 0);
        assert!((dividers[0].extra - 200.0).abs() < 1e-6);
    }

    #[test]
    fn collapsed_drawer_gets_fixed_rail_and_no_body() {
        let tree = PaneNode::Split {
            id: None,
            orientation: "horizontal".into(),
            children: vec![
                SplitChild {
                    size: 0.5,
                    node: PaneNode::Drawer {
                        id: 10,
                        current_index: 0,
                        expanded: false,
                        children: vec![GroupChild {
                            node: pane(1, "table"),
                        }],
                    },
                },
                SplitChild {
                    size: 0.5,
                    node: pane(2, "board"),
                },
            ],
        };
        let rects = layout_tree(&tree, Rect::new(0.0, 0.0, 200.0, 100.0), &LayoutMetrics::default(), None, None);

        let rail: Vec<_> = rects.iter().filter(|r| r.kind == CellKind::DrawerRail).collect();
        assert_eq!(rail.len(), 1);
        assert_eq!(rail[0].rect, Rect::new(0.0, 0.0, 36.0, 100.0));

        // Collapsed drawer emits no body/frame/content for its child.
        assert!(rects.iter().all(|r| r.id != 1));

        let content: Vec<_> = rects.iter().filter(|r| r.kind == CellKind::Content).collect();
        assert_eq!(content.len(), 1);
        assert_eq!(content[0].id, 2);
        assert_eq!(content[0].rect, Rect::new(36.0, 32.0, 164.0, 68.0));
    }

    #[test]
    fn bare_pane_header_carries_no_owning_group() {
        let tree = pane(1, "board");
        let rects = layout_tree(&tree, Rect::new(0.0, 0.0, 100.0, 100.0), &LayoutMetrics::default(), Some(1), None);

        let headers: Vec<_> = rects.iter().filter(|r| r.kind == CellKind::Header).collect();
        assert_eq!(headers.len(), 1);
        assert_eq!(headers[0].id, 1);
        assert_eq!(headers[0].child_id, -1);
        assert!(headers[0].active); // matches the passed-in active_leaf_id
        assert_eq!(headers[0].rect, Rect::new(0.0, 0.0, 100.0, 32.0));
    }

    #[test]
    fn tabs_header_tracks_active_child_and_owning_group() {
        let tree = PaneNode::Tabs {
            id: 5,
            current_index: 1,
            children: vec![
                GroupChild { node: pane(1, "board") },
                GroupChild { node: pane(2, "calendar") },
            ],
        };
        let rects = layout_tree(&tree, Rect::new(0.0, 0.0, 200.0, 100.0), &LayoutMetrics::default(), Some(5), None);

        let headers: Vec<_> = rects.iter().filter(|r| r.kind == CellKind::Header).collect();
        assert_eq!(headers.len(), 1);
        // The active child (index 1, pane 2) is what the header's grip
        // would drag -- not the inactive tab (pane 1).
        assert_eq!(headers[0].id, 2);
        assert_eq!(headers[0].child_id, 5);
        assert_eq!(headers[0].index, 1);
        assert!(headers[0].active); // active_leaf_id matches the *group* id
    }

    #[test]
    fn maximized_leaf_renders_alone_at_full_viewport() {
        let tree = PaneNode::Split {
            id: Some(0),
            orientation: "horizontal".into(),
            children: vec![
                SplitChild { size: 0.5, node: pane(1, "board") },
                SplitChild { size: 0.5, node: pane(2, "table") },
            ],
        };
        let viewport = Rect::new(0.0, 0.0, 200.0, 100.0);
        let rects = layout_tree(&tree, viewport, &LayoutMetrics::default(), None, Some(2));

        // Only pane 2's own subtree renders -- pane 1 is entirely absent,
        // not just visually hidden.
        assert!(rects.iter().all(|r| r.id != 1));
        let content: Vec<_> = rects.iter().filter(|r| r.kind == CellKind::Content).collect();
        assert_eq!(content.len(), 1);
        assert_eq!(content[0].id, 2);
        // Full viewport width, not its original 100px half-share.
        assert_eq!(content[0].rect.w, 200.0);
    }

    #[test]
    fn unresolvable_maximized_id_falls_back_to_the_whole_tree() {
        let tree = pane(1, "board");
        let rects = layout_tree(&tree, Rect::new(0.0, 0.0, 100.0, 100.0), &LayoutMetrics::default(), None, Some(999));
        assert!(rects.iter().any(|r| r.id == 1 && r.kind == CellKind::Content));
    }

    #[test]
    fn tabs_render_strip_add_button_and_active_body() {
        let tree = PaneNode::Tabs {
            id: 5,
            current_index: 1,
            children: vec![
                GroupChild { node: pane(1, "board") },
                GroupChild { node: pane(2, "calendar") },
            ],
        };
        let rects = layout_tree(&tree, Rect::new(0.0, 0.0, 200.0, 100.0), &LayoutMetrics::default(), None, None);

        let labels: Vec<_> = rects.iter().filter(|r| r.kind == CellKind::TabLabel).collect();
        assert_eq!(labels.len(), 2);
        assert!(!labels[0].active);
        assert!(labels[1].active);
        assert_eq!(labels[0].child_id, 1);
        assert_eq!(labels[1].child_id, 2);
        assert_eq!(labels[1].index, 1);

        let add: Vec<_> = rects.iter().filter(|r| r.kind == CellKind::TabAdd).collect();
        assert_eq!(add.len(), 1);
        assert_eq!(add[0].id, 5);

        let frames: Vec<_> = rects.iter().filter(|r| r.kind == CellKind::GroupFrame).collect();
        assert_eq!(frames.len(), 1);

        let content: Vec<_> = rects.iter().filter(|r| r.kind == CellKind::Content).collect();
        assert_eq!(content.len(), 1);
        assert_eq!(content[0].id, 2);
    }
}
