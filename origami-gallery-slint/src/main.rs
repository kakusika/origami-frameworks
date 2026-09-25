slint::include_modules!();

mod theme;

use std::cell::RefCell;
use std::rc::Rc;

use origami_slint::outline::{OutlineKind, OutlineRow, outline};
use origami_slint::layout::{CellKind, LayoutMetrics, PaneRect, Rect, layout_tree};
use origami_slint::edit::DividerDragBaseline;
use origami_slint::pane_tree::{GroupChild, PaneNode, PaneTree, SplitChild};
use serde_json::json;
use slint::{Model, ModelRc, SharedString, VecModel};

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

fn to_outline_row(r: &OutlineRow) -> PaneOutlineRow {
    PaneOutlineRow {
        depth: r.depth as i32,
        kind: SharedString::from(match r.kind {
            OutlineKind::Pane => "pane",
            OutlineKind::Tabs => "tabs",
            OutlineKind::Drawer => "drawer",
            OutlineKind::Split => "split",
        }),
        node_id: r.node_id.unwrap_or(-1),
        leaf_id: r.enclosing_leaf_id.unwrap_or(-1),
        title: SharedString::from(r.title.as_str()),
        view_type: SharedString::from(r.view_type.as_str()),
        child_count: r.child_count as i32,
        horizontal: r.horizontal,
        expanded: r.expanded,
        is_current_tab: r.is_current_tab,
        // The gallery keeps no active-leaf state of its own.
        active: false,
    }
}

struct AppState {
    tree: PaneTree,
    viewport: Rect,
    metrics: LayoutMetrics,
    maximized_leaf_id: Option<i32>,
    cells_model: Rc<VecModel<PaneCell>>,
    divider_drag: Option<DividerDragBaseline>,
}

fn relayout(state: &Rc<RefCell<AppState>>, app: &AppWindow) {
    let st = state.borrow();
    let rects = match &st.tree.root {
        Some(root) => layout_tree(root, st.viewport, &st.metrics, None, st.maximized_leaf_id),
        None => Vec::new(),
    };
    let cells: Vec<PaneCell> = rects.iter().map(to_cell).collect();
    let model = st.cells_model.clone();
    app.set_maximized_leaf_id(st.maximized_leaf_id.unwrap_or(-1));
    let outline_rows: Vec<PaneOutlineRow> = outline(st.tree.root.as_ref())
        .iter()
        .map(to_outline_row)
        .collect();
    drop(st);
    app.set_pane_outline(ModelRc::from(Rc::new(VecModel::from(outline_rows))));

    let new_len = cells.len();
    for (i, cell) in cells.into_iter().enumerate() {
        if i < model.row_count() {
            model.set_row_data(i, cell);
        } else {
            model.push(cell);
        }
    }
    while model.row_count() > new_len {
        model.remove(model.row_count() - 1);
    }
}

fn main() -> Result<(), slint::PlatformError> {
    let app = AppWindow::new()?;
    theme::apply_default(&app);

    let cells_model = Rc::new(VecModel::default());
    let state = Rc::new(RefCell::new(AppState {
        tree: PaneTree::new(Some(create_demo_tree())),
        viewport: Rect::new(0.0, 0.0, 1040.0, 660.0),
        metrics: LayoutMetrics::default(),
        maximized_leaf_id: None,
        cells_model: cells_model.clone(),
        divider_drag: None,
    }));

    app.set_pane_cells(ModelRc::from(cells_model));

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
                    state.borrow_mut().tree.toggle_drawer_expanded(drawer_id);
                }
                app.set_pane_status(format!("Toggled drawer {}", drawer_id).into());
                relayout(&state, &app);
            }
        });
    }

    // Structure viewer actions, applied with origami-panes' own tree edits.
    // "activate" only reports: the gallery keeps no active-leaf state.
    {
        let state = state.clone();
        let app_weak = app.as_weak();
        app.on_manager_action(move |node_id, leaf_id, name| {
            if let Some(app) = app_weak.upgrade() {
                {
                    let mut st = state.borrow_mut();
                    let tree = &mut st.tree;
                    match name.as_str() {
                        "toggle-expanded" => {
                            tree.toggle_drawer_expanded(node_id);
                        }
                        "convert-to-drawer" | "convert-to-tabs" => {
                            tree.convert_group(node_id);
                        }
                        "close-all-tabs" => {
                            tree.close_all_tabs(node_id);
                        }
                        "close-group" => {
                            tree.close_group(node_id);
                        }
                        "close" => {
                            // A pane inside a group closes as a tab; a
                            // standalone pane is its own leaf.
                            if leaf_id == node_id {
                                tree.remove_standalone(node_id);
                            } else {
                                tree.close_tab(leaf_id, node_id);
                            }
                        }
                        _ => {}
                    }
                    tree.prune_empty_groups(&[]);
                }
                app.set_pane_status(
                    format!("Manager: {} (node {}, leaf {})", name, node_id, leaf_id).into(),
                );
                relayout(&state, &app);
            }
        });
    }

    // Resize divider start
    {
        let state = state.clone();
        app.on_resize_divider_start(move |split_id, index| {
            let mut st = state.borrow_mut();
            st.divider_drag = st.tree.divider_baseline(split_id, index as usize);
        });
    }

    // Resize divider moving
    {
        let state = state.clone();
        let app_weak = app.as_weak();
        app.on_resize_divider(move |split_id, _index, pair_px, total_delta_px| {
            if let Some(app) = app_weak.upgrade() {
                let mut st = state.borrow_mut();
                let baseline = st.divider_drag.filter(|b| b.split_id == split_id);
                if let Some(baseline) = baseline {
                    st.tree.resize_pair(baseline, pair_px, total_delta_px);
                }
                drop(st);
                relayout(&state, &app);
            }
        });
    }

    // Resize divider end
    {
        let state = state.clone();
        app.on_resize_divider_end(move || {
            let mut st = state.borrow_mut();
            st.divider_drag = None;
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

    // EditableListView interactive handlers
    let list_model = Rc::new(VecModel::from(vec![
        EditableListEntry { label: "Layer 1 (Background)".into() },
        EditableListEntry { label: "Layer 2 (Main Art)".into() },
        EditableListEntry { label: "Layer 3 (Overlay)".into() },
    ]));
    app.set_editable_items(ModelRc::from(list_model.clone()));

    {
        let list_model = list_model.clone();
        app.on_list_add_requested(move || {
            let next_num = list_model.row_count() + 1;
            list_model.push(EditableListEntry {
                label: format!("Layer {} (New)", next_num).into(),
            });
        });
    }

    {
        let list_model = list_model.clone();
        app.on_list_remove_requested(move |index| {
            let idx = index as usize;
            if idx < list_model.row_count() {
                list_model.remove(idx);
            }
        });
    }

    {
        let list_model = list_model.clone();
        app.on_list_move_up_requested(move |index| {
            let idx = index as usize;
            if idx > 0 && idx < list_model.row_count() {
                let a = list_model.row_data(idx).unwrap();
                let b = list_model.row_data(idx - 1).unwrap();
                list_model.set_row_data(idx - 1, a);
                list_model.set_row_data(idx, b);
            }
        });
    }

    {
        let list_model = list_model.clone();
        app.on_list_move_down_requested(move |index| {
            let idx = index as usize;
            if idx + 1 < list_model.row_count() {
                let a = list_model.row_data(idx).unwrap();
                let b = list_model.row_data(idx + 1).unwrap();
                list_model.set_row_data(idx + 1, a);
                list_model.set_row_data(idx, b);
            }
        });
    }

    app.run()
}
