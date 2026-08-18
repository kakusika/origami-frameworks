use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn main() {
    println!("cargo:rerun-if-changed=qml");
    println!("cargo:rerun-if-changed=src/cxxqt_object.rs");

    CxxQtBuilder::new_qml_module(
        QmlModule::new("la.cettila.Origami")
            .qml_files([
                QmlFile::from("qml/pane/PaneContext.qml").singleton(true),
                QmlFile::from("qml/pane/PaneBackdrop.qml").singleton(true),
                QmlFile::from("qml/pane/PaneWindowRegistry.qml").singleton(true),
                QmlFile::from("qml/widgets/impl/ErrorBus.qml").singleton(true),
                QmlFile::from("qml/widgets/impl/ToastBus.qml").singleton(true),
            ])
            .qml_files([
                //[ Pane ]
                "qml/pane/PaneView.qml",
                "qml/pane/PaneNode.qml",
                "qml/pane/PaneLeaf.qml",
                "qml/pane/PaneToolbar.qml",
                "qml/pane/PaneHeader.qml",
                "qml/pane/PaneWindow.qml",
                "qml/pane/PaneManager.qml",
                "qml/pane/PaneManagerRow.qml",
                "qml/pane/PaneDropOverlay.qml",
                "qml/pane/ViewTypePickerButton.qml",
                "qml/pane/ViewTypePickerPopup.qml",
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
                "qml/regions/header/HeaderBar.qml",
                "qml/regions/header/HeaderBarRow.qml",
                "qml/regions/header/HeaderMenuButton.qml",
                "qml/regions/header/HeaderMenuCoordinator.qml",
                "qml/regions/header/HeaderMenuGroup.qml",
                "qml/regions/header/MultiRowHeaderBar.qml",
                "qml/regions/panel/CollapsiblePanel.qml",
                "qml/regions/sidebar/SideTitleBar.qml",
                "qml/regions/statusbar/StatusBar.qml",
            ]),
    )
    .files(["src/cxxqt_object.rs"])
    .qt_module("Quick")
    .qt_module("QuickControls2")
    .build()
    .export();
}
