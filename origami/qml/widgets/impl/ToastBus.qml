pragma Singleton
import QtQuick

// Singleton event bus for posting transient toast notification messages app-wide.
QtObject {
    id: bus

    // type can be "info", "success", "warning", "negative"
    signal showToast(string message, string iconName, string type, int durationMs)

    function post(message, iconName, type, durationMs) {
        bus.showToast(message, iconName || "dialog-information-symbolic", type || "info", durationMs || 3000);
    }

    function info(message) {
        bus.post(message, "dialog-information-symbolic", "info", 3000);
    }

    function success(message) {
        bus.post(message, "emblem-success-symbolic", "success", 3000);
    }

    function warning(message) {
        bus.post(message, "dialog-warning-symbolic", "warning", 4000);
    }

    function error(message) {
        bus.post(message, "dialog-error-symbolic", "negative", 5000);
    }
}
