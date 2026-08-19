import QtQuick

// Helper object for recursive pane tree operations.
QtObject {
    id: root

    function cloneNode(node) {
        if (!node)
            return null;
        if (node.type === "pane" || node.type === "toolbar") {
            return {
                type: node.type,
                id: node.id,
                title: node.title,
                component: node.component,
                viewType: node.viewType,
                item: node.item,
                props: node.props,
                fixedSize: node.fixedSize || 0
            };
        }
        if (node.type === "tabs") {
            return {
                type: "tabs",
                id: node.id,
                currentIndex: node.currentIndex,
                children: (node.children || []).map(function (c) {
                    return {
                        node: cloneNode(c.node)
                    };
                })
            };
        }
        if (node.type === "drawer") {
            return {
                type: "drawer",
                id: node.id,
                expanded: node.expanded,
                orientation: node.orientation,
                overlayWidth: node.overlayWidth,
                overlayHeight: node.overlayHeight,
                currentIndex: node.currentIndex,
                children: (node.children || []).map(function (c) {
                    return {
                        node: cloneNode(c.node)
                    };
                })
            };
        }
        return {
            type: "split",
            id: node.id,
            orientation: node.orientation,
            children: (node.children || []).map(function (c) {
                return {
                    size: c.size,
                    node: cloneNode(c.node)
                };
            })
        };
    }

    function findNode(node, targetId, parentChildren, indexInParent, parentNode) {
        if (!node)
            return null;
        if (node.id === targetId) {
            return {
                node: node,
                parentNode: parentNode || null,
                parentChildren: parentChildren,
                index: indexInParent
            };
        }
        if (node.type === "split" || node.type === "drawer") {
            for (var i = 0; i < (node.children || []).length; i++) {
                var found = findNode(node.children[i].node, targetId, node.children, i, node);
                if (found)
                    return found;
            }
        }
        return null;
    }

    function findArea(node, areaId) {
        if (!node)
            return null;
        if (node.type === "pane" || node.type === "tabs" || node.type === "toolbar")
            return node.id === areaId ? node : null;
        if (node.type === "drawer" && node.id === areaId)
            return node;
        for (var i = 0; i < (node.children || []).length; i++) {
            var found = findArea(node.children[i].node, areaId);
            if (found)
                return found;
        }
        return null;
    }

    function findPane(node, paneId) {
        if (!node)
            return null;
        if (node.type === "pane")
            return node.id === paneId ? node : null;
        if (node.children) {
            for (var i = 0; i < node.children.length; i++) {
                var found = findPane(node.children[i].node, paneId);
                if (found)
                    return found;
            }
        }
        return null;
    }

    function isGroupType(type) {
        return type === "tabs" || type === "drawer";
    }

    function renormalizeSizes(node) {
        if (!node || node.type !== "split" || !node.children || node.children.length === 0)
            return;
        var total = 0;
        for (var i = 0; i < node.children.length; i++) {
            total += node.children[i].size;
        }
        if (total <= 0)
            return;
        for (var j = 0; j < node.children.length; j++) {
            node.children[j].size /= total;
        }
    }

    function paneNode(pane) {
        if (!pane)
            return null;
        return {
            type: "pane",
            id: pane.id,
            title: pane.title,
            component: pane.component,
            viewType: pane.viewType,
            item: pane.item,
            props: pane.props
        };
    }

    function tabsChild(pane) {
        return {
            node: paneNode(pane)
        };
    }
}
