slint::include_modules!();

mod theme;

use std::cell::RefCell;
use std::rc::Rc;

use origami_slint::layout::{CellKind, LayoutMetrics, PaneRect, Rect, layout_tree};
use origami_slint::pane_tree::{GroupChild, PaneNode, PaneTree, SplitChild};
use serde_json::json;
use slint::{ModelRc, SharedString, VecModel};

fn create_demo_tree() -> PaneNode {
    PaneNode::Split {
        id: Some(0),
        orientation: "horizontal".into(),
        children: vec![
            SplitChild {
                size: 0.25,
                node: PaneNode::Drawer {
                    id: 1,
                    current_index: 0,
                    expanded: true,
                    children: vec![GroupChild {
                        node: PaneNode::Pane {
                            id: 2,
                            title: "Explorer".into(),
                            view_type: "notes".into(),
                            props: json!({}),
                        },
                    }],
                },
            },
            SplitChild {
                size: 0.45,
                node: PaneNode::Tabs {
                    id: 3,
                    current_index: 0,
                    children: vec![
                        GroupChild {
                            node: PaneNode::Pane {
                                id: 4,
                                title: "Kanban Board".into(),
                                view_type: "board".into(),
                                props: json!({}),
                            },
                        },
                        GroupChild {
                            node: PaneNode::Pane {
                                id: 5,
                                title: "Schedule".into(),
                                view_type: "calendar".into(),
                                props: json!({}),
                            },
                        },
                    ],
                },
            },
            SplitChild {
                size: 0.30,
                node: PaneNode::Pane {
                    id: 6,
                    title: "Notes".into(),
                    view_type: "notes".into(),
                    props: json!({}),
                },
            },
        ],
    }
}

fn kind_str(kind: CellKind) -> &'static str {
    match kind {
        CellKind::Content => "content",
        CellKind::TabLabel => "tab-label",
        CellKind::TabAdd => "tab-add",
        CellKind::DrawerRail => "drawer-rail",
        CellKind::Divider => "divider",
        CellKind::GroupFrame => "group-frame",
        CellKind::Leaf => "leaf",
        CellKind::Header => "header",
    }
}

fn to_cell(r: &PaneRect) -> PaneCell {
    PaneCell {
        x: r.rect.x,
        y: r.rect.y,
        width: r.rect.w,
        height: r.rect.h,
        z: r.z,
        kind: SharedString::from(kind_str(r.kind)),
        id: r.id,
        child_id: r.child_id,
        index: r.index,
        extra: r.extra,
        view_type: SharedString::from(r.view_type.as_str()),
        title: SharedString::from(r.title.as_str()),
        active: r.active,
    }
}

struct AppState {
    tree: PaneTree,
    viewport: Rect,
    metrics: LayoutMetrics,
    maximized_leaf_id: Option<i32>,
}

fn relayout(state: &Rc<RefCell<AppState>>, app: &AppWindow) {
    let st = state.borrow();
    let rects = match &st.tree.root {
        Some(root) => layout_tree(root, st.viewport, &st.metrics, None, st.maximized_leaf_id),
        None => Vec::new(),
    };
    let cells: Vec<PaneCell> = rects.iter().map(to_cell).collect();
    let model = Rc::new(VecModel::from(cells));
    app.set_pane_cells(ModelRc::from(model));
    app.set_maximized_leaf_id(st.maximized_leaf_id.unwrap_or(-1));
}

fn main() -> Result<(), slint::PlatformError> {
    let app = AppWindow::new()?;
    theme::load_and_apply(&app);

    let state = Rc::new(RefCell::new(AppState {
        tree: PaneTree::new(Some(create_demo_tree())),
        viewport: Rect::new(0.0, 0.0, 1040.0, 660.0),
        metrics: LayoutMetrics::default(),
        maximized_leaf_id: None,
    }));

    // Initial layout
    relayout(&state, &app);

    // Relayout on size change
    {
        let state = state.clone();
        let app_weak = app.as_weak();
        app.on_relayout(move |w, h| {
            if let Some(app) = app_weak.upgrade() {
                {
                    let mut st = state.borrow_mut();
                    st.viewport = Rect::new(0.0, 0.0, w, h);
                }
                relayout(&state, &app);
            }
        });
    }

    // Tab selection
    {
        let state = state.clone();
        let app_weak = app.as_weak();
        app.on_select_tab(move |group_id, index| {
            if let Some(app) = app_weak.upgrade() {
                {
                    let mut st = state.borrow_mut();
                    if let Some(root) = st.tree.root.as_mut() {
                        if let Some(PaneNode::Tabs { current_index, .. }) = root.find_node_mut(group_id) {
                            *current_index = index as usize;
                        }
                    }
                }
                app.set_pane_status(format!("Switched to tab index {} in group {}", index, group_id).into());
                relayout(&state, &app);
            }
        });
    }

    // Toggle drawer
    {
        let state = state.clone();
        let app_weak = app.as_weak();
        app.on_toggle_drawer(move |drawer_id| {
            if let Some(app) = app_weak.upgrade() {
                {
                    let mut st = state.borrow_mut();
                    if let Some(root) = st.tree.root.as_mut() {
                        if let Some(PaneNode::Drawer { expanded, .. }) = root.find_node_mut(drawer_id) {
                            *expanded = !*expanded;
                        }
                    }
                }
                app.set_pane_status(format!("Toggled drawer {}", drawer_id).into());
                relayout(&state, &app);
            }
        });
    }

    // Resize divider
    {
        let state = state.clone();
        let app_weak = app.as_weak();
        app.on_resize_divider(move |split_id, index, _extra, delta| {
            if let Some(app) = app_weak.upgrade() {
                {
                    let mut st = state.borrow_mut();
                    let vw = st.viewport.w;
                    let vh = st.viewport.h;
                    if let Some(root) = st.tree.root.as_mut() {
                        if let Some(PaneNode::Split { children, orientation, .. }) = root.find_node_mut(split_id) {
                            let total_px = if orientation == "horizontal" { vw } else { vh };
                            let idx = index as usize;
                            if total_px > 0.0 && idx + 1 < children.len() {
                                let frac_delta = delta as f64 / total_px as f64;
                                let orig_a = children[idx].size;
                                let orig_b = children[idx + 1].size;
                                let min_frac = 0.05;
                                let new_a = (orig_a + frac_delta).max(min_frac);
                                let sum = orig_a + orig_b;
                                if new_a < sum - min_frac {
                                    children[idx].size = new_a;
                                    children[idx + 1].size = sum - new_a;
                                }
                            }
                        }
                    }
                }
                relayout(&state, &app);
            }
        });
    }

    // Toggle maximize
    {
        let state = state.clone();
        let app_weak = app.as_weak();
        app.on_toggle_maximize(move |leaf_id| {
            if let Some(app) = app_weak.upgrade() {
                {
                    let mut st = state.borrow_mut();
                    st.maximized_leaf_id = if st.maximized_leaf_id == Some(leaf_id) {
                        None
                    } else {
                        Some(leaf_id)
                    };
                }
                relayout(&state, &app);
            }
        });
    }

    app.run()
}
