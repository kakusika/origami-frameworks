import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0

// Popup content for ViewTypePickerButton.qml -- a pinned search field at
// the top plus a category-grouped, filtered list below. Kept as its own
// file (rather than inlined into ViewTypePickerButton.qml) purely for
// readability -- the two are a single logical unit, always used together;
// see that file's own class comment for the design rationale (a dedicated
// themed Popup, not a QQC2.Menu, so a live TextField can sit inside it).
QQC2.Popup {
    id: root

    // See ViewTypePickerButton.qml's own class comment for this shape.
    property var categories: []

    // See ViewTypePickerButton.qml's own selectedViewType comment.
    property string selectedViewType: ""

    signal viewTypeSelected(string viewType, string title)

    readonly property var colors: Theme.paletteFor(Theme.view)

    // Same modal/dim pairing ThemedMenu.qml uses, and for the same reason
    // (see its own comment): without modal: true, a press on this popup's
    // own content also reaches whatever view sits behind it, which can
    // steal focus and close this popup before onTriggered/onClicked ever
    // fires.
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
    modal: true
    dim: false

    // See widgets/Popup.qml's own detachedWindow comment: this is one of
    // the two call sites that actually need to draw past the app window's
    // own edge -- a category-grouped, ~20-entry list needs real room, and
    // this popup can be triggered from anywhere a pane's header/tab strip
    // happens to sit, including flush against a split cell's own edge.
    // Needs a live search TextField below to actually accept typing --
    // see that same comment for why this depends on qtwayland actually
    // being present at runtime.
    popupType: QQC2.Popup.Item

    property string _searchText: ""
    property int _highlightIndex: -1

    // `categories` flattened into one row per list entry: either
    // {kind: "header", text} or {kind: "item", entry}. Headers are only
    // emitted while _searchText is empty -- typing collapses the grouped
    // view to a flat match list (matched on title/viewType/category, case-
    // insensitive), same as Blender's own editor-type switcher; clearing
    // the field restores the grouped view.
    readonly property var _rows: {
        var rows = [];
        var query = root._searchText.trim().toLowerCase();
        for (var i = 0; i < root.categories.length; i++) {
            var group = root.categories[i];
            var matched = [];
            for (var j = 0; j < group.items.length; j++) {
                var entry = group.items[j];
                if (query === "" || entry.title.toLowerCase().indexOf(query) !== -1 || (entry.viewType || "").toLowerCase().indexOf(query) !== -1 || group.category.toLowerCase().indexOf(query) !== -1)
                    matched.push(entry);
            }
            if (matched.length === 0)
                continue;
            if (query === "")
                rows.push({
                    kind: "header",
                    text: group.category
                });
            for (var k = 0; k < matched.length; k++)
                rows.push({
                    kind: "item",
                    entry: matched[k]
                });
        }
        return rows;
    }

    function _firstItemIndex() {
        for (var i = 0; i < root._rows.length; i++)
            if (root._rows[i].kind === "item")
                return i;
        return -1;
    }

    // Fresh on every open, not just once -- otherwise a leftover query
    // from the previous open would silently pre-filter the list the next
    // time this popup shows.
    onAboutToShow: {
        searchField.text = "";
        root._searchText = "";
        root._highlightIndex = -1;
    }
    onOpened: searchField.forceActiveFocus()

    // Moves the highlight to the next/previous "item" row, skipping over
    // "header" rows (Up/Down should never land the highlight on an
    // inert category label). Wraps around at either end.
    function _moveHighlight(delta) {
        if (root._rows.length === 0)
            return;
        var idx = root._highlightIndex;
        for (var step = 0; step < root._rows.length; step++) {
            idx += delta;
            if (idx < 0)
                idx = root._rows.length - 1;
            else if (idx >= root._rows.length)
                idx = 0;
            if (root._rows[idx].kind === "item") {
                root._highlightIndex = idx;
                listView.positionViewAtIndex(idx, ListView.Contain);
                return;
            }
        }
    }

    // Activates whichever entry is highlighted -- defaulting to the first
    // match if the user hasn't touched Up/Down/hover yet, so pressing
    // Enter right after typing a query still does the obvious thing.
    function _activateHighlighted() {
        var idx = root._highlightIndex >= 0 ? root._highlightIndex : root._firstItemIndex();
        if (idx < 0 || idx >= root._rows.length)
            return;
        root._choose(root._rows[idx].entry);
    }

    function _choose(entry) {
        root.viewTypeSelected(entry.viewType, entry.title);
        root.close();
    }

    width: Units.gridUnit * 18

    readonly property real _maxListHeight: Units.gridUnit * 18
    readonly property real _minListHeight: Units.gridUnit * 2.4
    // Fits the list to its own content up to _maxListHeight (beyond which
    // listView below scrolls instead), floored at _minListHeight so the
    // "no matches" empty state (centered in that same area) always has
    // room to actually show, rather than being squeezed into a
    // near-zero-height sliver when _rows is empty.
    readonly property real _listAreaHeight: Math.min(root._maxListHeight, Math.max(root._minListHeight, listView.contentHeight))

    height: searchField.height + Units.smallSpacing + root._listAreaHeight + root.topPadding + root.bottomPadding

    contentItem: Column {
        spacing: Units.smallSpacing

        QQC2.TextField {
            id: searchField
            width: root.width - root.leftPadding - root.rightPadding
            placeholderText: "検索"
            onTextChanged: {
                root._searchText = text;
                root._highlightIndex = root._firstItemIndex();
            }
            onAccepted: root._activateHighlighted()
            Keys.onDownPressed: root._moveHighlight(1)
            Keys.onUpPressed: root._moveHighlight(-1)
        }

        Item {
            width: root.width - root.leftPadding - root.rightPadding
            height: root._listAreaHeight

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                model: root._rows

                QQC2.ScrollIndicator.vertical: QQC2.ScrollIndicator {}

                delegate: Item {
                    id: rowDelegate
                    required property var modelData
                    required property int index

                    readonly property bool _isHeader: rowDelegate.modelData.kind === "header"
                    readonly property var _entry: rowDelegate.modelData.entry
                    readonly property bool _selected: !rowDelegate._isHeader && rowDelegate._entry.viewType === root.selectedViewType
                    readonly property bool _highlighted: rowDelegate.index === root._highlightIndex || rowDelegate._selected

                    width: listView.width
                    height: rowDelegate._isHeader ? headerLabel.implicitHeight + Units.smallSpacing : Units.gridUnit * 1.6

                    Label {
                        id: headerLabel
                        visible: rowDelegate._isHeader
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Units.smallSpacing
                        type: "secondary"
                        text: rowDelegate._isHeader ? rowDelegate.modelData.text : ""
                    }

                    Rectangle {
                        visible: !rowDelegate._isHeader
                        anchors.fill: parent
                        radius: Units.cornerRadius
                        color: rowDelegate._highlighted ? root.colors.highlightColor : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Units.smallSpacing
                            spacing: Units.smallSpacing

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !rowDelegate._isHeader && (rowDelegate._entry.icon || "") !== ""
                                color: rowDelegate._highlighted ? root.colors.highlightedTextColor : root.colors.textColor
                                source: rowDelegate._isHeader ? "" : (rowDelegate._entry.icon || "")
                                width: Units.iconSizes.small
                                height: Units.iconSizes.small
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: rowDelegate._isHeader ? "" : rowDelegate._entry.title
                                color: rowDelegate._highlighted ? root.colors.highlightedTextColor : root.colors.textColor
                            }
                        }

                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered)
                                    root._highlightIndex = rowDelegate.index;
                            }
                        }

                        TapHandler {
                            onTapped: root._choose(rowDelegate._entry)
                        }
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: root._rows.length === 0
                type: "secondary"
                text: "一致する項目がありません"
            }
        }
    }
}
