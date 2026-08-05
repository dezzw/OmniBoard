//! Typed error catalog aligned with packages/protocol/registries/error-codes.json.

use serde_json::Value;
use thiserror::Error;

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
pub enum ErrorCode {
    ParseError = -32700,
    InvalidRequest = -32600,
    MethodNotFound = -32601,
    InvalidParams = -32602,
    InternalError = -32603,
    ProviderCrash = -32000,
    Timeout = -32001,
    AuthExpired = -32002,
    PermissionDenied = -32003,
    InvalidRender = -32004,
    RateLimited = -32005,
    StaleData = -32006,
    Unavailable = -32007,
    SyncConflict = -32008,
    NotFound = -32010,
}

impl ErrorCode {
    pub fn as_i32(self) -> i32 {
        self as i32
    }

    pub fn name(self) -> &'static str {
        match self {
            Self::ParseError => "ParseError",
            Self::InvalidRequest => "InvalidRequest",
            Self::MethodNotFound => "MethodNotFound",
            Self::InvalidParams => "InvalidParams",
            Self::InternalError => "InternalError",
            Self::ProviderCrash => "ProviderCrash",
            Self::Timeout => "Timeout",
            Self::AuthExpired => "AuthExpired",
            Self::PermissionDenied => "PermissionDenied",
            Self::InvalidRender => "InvalidRender",
            Self::RateLimited => "RateLimited",
            Self::StaleData => "StaleData",
            Self::Unavailable => "Unavailable",
            Self::SyncConflict => "SyncConflict",
            Self::NotFound => "NotFound",
        }
    }
}

#[derive(Debug, Error)]
pub enum Error {
    #[error("{code:?}: {message}")]
    App {
        code: ErrorCode,
        message: String,
        data: Option<Value>,
    },
    #[error(transparent)]
    Db(#[from] rusqlite::Error),
    #[error(transparent)]
    Json(#[from] serde_json::Error),
    #[error(transparent)]
    Io(#[from] std::io::Error),
}

impl Error {
    pub fn app(code: ErrorCode, message: impl Into<String>) -> Self {
        Self::App {
            code,
            message: message.into(),
            data: None,
        }
    }

    pub fn code(&self) -> ErrorCode {
        match self {
            Self::App { code, .. } => *code,
            Self::Db(_) | Self::Json(_) | Self::Io(_) => ErrorCode::InternalError,
        }
    }
}
