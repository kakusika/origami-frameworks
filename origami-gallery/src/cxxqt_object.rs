use cxx_qt::CxxQtType;
use std::pin::Pin;

#[cxx_qt::bridge]
mod ffi {
    unsafe extern "C++" {
        include!(<QtQml/qqmlregistration.h>);
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(i32, click_count)]
        #[qproperty(QString, status_message)]
        type QmlMinimalHelper = super::QmlMinimalHelperRust;

        #[qinvokable]
        fn increment(self: Pin<&mut QmlMinimalHelper>);

        #[qinvokable]
        fn reset(self: Pin<&mut QmlMinimalHelper>);
    }
}

pub struct QmlMinimalHelperRust {
    click_count: i32,
    status_message: cxx_qt_lib::QString,
}

impl Default for QmlMinimalHelperRust {
    fn default() -> Self {
        Self {
            click_count: 0,
            status_message: cxx_qt_lib::QString::from("QQC2 Gallery initialized."),
        }
    }
}

impl ffi::QmlMinimalHelper {
    fn increment(mut self: Pin<&mut Self>) {
        let new_count = self.rust().click_count + 1;
        let msg = format!("Button clicked {} times", new_count);
        self.as_mut().set_click_count(new_count);
        self.as_mut()
            .set_status_message(cxx_qt_lib::QString::from(&msg));
    }

    fn reset(mut self: Pin<&mut Self>) {
        self.as_mut().set_click_count(0);
        self.as_mut()
            .set_status_message(cxx_qt_lib::QString::from("Reset to defaults."));
    }
}
