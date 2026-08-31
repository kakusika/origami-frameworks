//! The app identity `vault.rs`/`settings.rs` resolve paths against --
//! `directories::ProjectDirs`'s qualifier/organization/application triple
//! (the OS-level per-user config directory) and the subfolder name a vault
//! root's own config files live under (historically always literally
//! `.cettila`, wherever a function joined that path segment directly).
//!
//! This crate has exactly one real consumer today (cettila), so both were
//! simply hardcoded inline at each call site. A `OnceLock`-backed global,
//! set once via `set_app_identity()` (call it early in an app's own
//! `main()`, before any other function in this crate runs), replaces that:
//! a caller that never calls it gets cettila's own original identity back
//! unchanged (the `get_or_init` default below), so every existing call
//! site across cettila keeps working with zero changes. A different app
//! wanting its own separate config location calls `set_app_identity()`
//! once at its own startup instead.
//!
//! Deliberately not threaded through every function's own argument list
//! instead: `active_vault_root()` alone (see `vault.rs`) already has
//! upwards of a dozen call sites scattered across cettila's own crates --
//! a plain function-argument change would mean updating every one of them
//! for a decoupling that doesn't actually need it, since a global set once
//! at startup serves the same purpose without touching any of them.

use std::sync::OnceLock;

pub struct AppIdentity {
    pub qualifier: String,
    pub organization: String,
    pub application: String,
    pub vault_namespace: String,
}

static APP_IDENTITY: OnceLock<AppIdentity> = OnceLock::new();

/// Sets the identity every path-resolving function in this crate reads.
/// Only the first call (across the whole process) has any effect -- same
/// "set once at startup" contract `OnceLock` itself gives; a later call
/// (e.g. from a second app embedding this crate transitively) is silently
/// ignored rather than switching an already-running app's config location
/// out from under it.
pub fn set_app_identity(qualifier: &str, organization: &str, application: &str, vault_namespace: &str) {
    let _ = APP_IDENTITY.set(AppIdentity {
        qualifier: qualifier.to_string(),
        organization: organization.to_string(),
        application: application.to_string(),
        vault_namespace: vault_namespace.to_string(),
    });
}

/// cettila's own original hardcoded identity -- see this module's own doc
/// comment for why this is the default rather than requiring every
/// existing call site to opt in explicitly.
pub(crate) fn app_identity() -> &'static AppIdentity {
    APP_IDENTITY.get_or_init(|| AppIdentity {
        qualifier: "dev".to_string(),
        organization: "cettila".to_string(),
        application: "cettila".to_string(),
        vault_namespace: "cettila".to_string(),
    })
}
