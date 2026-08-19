use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn main() {
    println!("cargo:rerun-if-changed=qml");
    println!("cargo:rerun-if-changed=src/cxxqt_object.rs");

    CxxQtBuilder::new_qml_module(
        QmlModule::new("la.cettila.Origami")
            .qml_files([
                QmlFile::from("qml/pane/core/PaneContext.qml").singleton(true),
                QmlFile::from("qml/pane/core/PaneBackdrop.qml").singleton(true),
                QmlFile::from("qml/pane/window/PaneWindowRegistry.qml").singleton(true),
                QmlFile::from("qml/widgets/impl/ErrorBus.qml").singleton(true),
                QmlFile::from("qml/widgets/impl/ToastBus.qml").singleton(true),
            ])
            .qml_files([
                //[ Pane - core ]
                "qml/pane/core/PaneView.qml",
                "qml/pane/core/PaneNode.qml",
                "qml/pane/core/PaneLeaf.qml",
                "qml/pane/core/PaneDropOverlay.qml",
                "qml/pane/core/PaneTreeOps.qml",
                //[ Pane - header ]
                "qml/pane/header/PaneToolbar.qml",
                "qml/pane/header/PaneHeader.qml",
                "qml/pane/header/PaneGrip.qml",
                //[ Pane - window ]
                "qml/pane/window/PaneWindow.qml",
                //[ Pane - manager ]
                "qml/pane/manager/PaneManager.qml",
                "qml/pane/manager/PaneManagerRow.qml",
                //[ Pane - picker ]
                "qml/pane/picker/ViewTypePickerButton.qml",
                "qml/pane/picker/ViewTypePickerPopup.qml",
                //[ Pane - groups ]
                "qml/pane/groups/PaneSplit.qml",
                "qml/pane/groups/PaneDrawer.qml",
                "qml/pane/groups/PaneTabs.qml",
                "qml/pane/groups/PaneTabBar.qml",
                "qml/pane/groups/PaneTabHeader.qml",
                "qml/pane/groups/PaneMaximizeBar.qml",
                //[ Widgets - buttons ]
                "qml/widgets/buttons/ActionButton.qml",
                "qml/widgets/buttons/ActionButtonGroup.qml",
                "qml/widgets/buttons/DropdownButton.qml",
                "qml/widgets/buttons/HamburgerButton.qml",
                "qml/widgets/buttons/IconButton.qml",
                "qml/widgets/buttons/ToggleButton.qml",
                "qml/widgets/buttons/ToggleGroup.qml",
                //[ Widgets - controls ]
                "qml/widgets/controls/ColorSwatch.qml",
                "qml/widgets/controls/DragHandle.qml",
                "qml/widgets/controls/Icon.qml",
                "qml/widgets/controls/IconStack.qml",
                "qml/widgets/controls/Label.qml",
                "qml/widgets/controls/Separator.qml",
                "qml/widgets/controls/Slider.qml",
                //[ Widgets - inputs ]
                "qml/widgets/inputs/NumberInput.qml",
                //[ Widgets - menus ]
                "qml/widgets/menus/ThemedMenu.qml",
                "qml/widgets/menus/ThemedSubMenu.qml",
                //[ Widgets - popups ]
                "qml/widgets/popups/ColorPickerPopup.qml",
                "qml/widgets/popups/ConfirmDialog.qml",
                "qml/widgets/popups/IoErrorBanner.qml",
                "qml/widgets/popups/ToastNotification.qml",
                //[ Views ]
                "qml/views/Breadcrumb.qml",
                "qml/views/EditableListView.qml",
                "qml/views/FileTile.qml",
                "qml/views/CollapsibleSection.qml",
                "qml/views/CollapsibleTextField.qml",
                //[ Regions ]
                "qml/regions/bar/Bar.qml",
                "qml/regions/bar/BarRow.qml",
                "qml/regions/bar/MultiRowBar.qml",
                "qml/regions/header/HeaderMenuButton.qml",
                "qml/regions/header/HeaderMenuCoordinator.qml",
                "qml/regions/header/HeaderMenuGroup.qml",
                "qml/regions/panel/CollapsiblePanel.qml",
                "qml/regions/sidebar/SideTitleBar.qml",
                "qml/regions/statusbar/StatusBar.qml",
            ]),
    )
    .files(["src/cxxqt_object.rs"])
    .qt_module("Quick")
    .qt_module("QuickControls2")
    .build()
    .reexport_dependency("ayame")
    .export();
}
