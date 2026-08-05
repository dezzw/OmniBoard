//! OmniBoard Core — local runtime library.
//!
//! See `docs/architecture/` for normative contracts. Built with the repo Nix flake:
//! `nix develop -c cargo test --manifest-path core/Cargo.toml`

pub mod client;
pub mod error;
pub mod event;
pub mod framing;
pub mod item;
pub mod opp;
pub mod render;
pub mod store;
pub mod supervisor;

pub use error::{Error, ErrorCode, Result};
pub use item::{Item, ItemId};
pub use store::ItemStore;
pub use supervisor::{ProviderSupervisor, SupervisorConfig};
