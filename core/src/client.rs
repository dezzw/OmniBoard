//! Minimal Client Protocol over a local Unix socket (JSON-RPC + Content-Length).

use std::path::Path;
use std::sync::{Arc, Mutex};

use serde_json::{json, Value};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{UnixListener, UnixStream};
use tracing::{info, warn};

use crate::error::{Error, ErrorCode, Result};
use crate::event::EventBus;
use crate::framing::{encode_frame, FrameDecoder};
use crate::item::ItemId;
use crate::store::ItemStore;

pub struct ClientServer {
    store: Arc<Mutex<ItemStore>>,
    #[allow(dead_code)]
    bus: Arc<EventBus>,
}

impl ClientServer {
    pub fn new(store: Arc<Mutex<ItemStore>>, bus: Arc<EventBus>) -> Self {
        Self { store, bus }
    }

    pub async fn listen(&self, socket_path: impl AsRef<Path>) -> Result<()> {
        let path = socket_path.as_ref();
        if path.exists() {
            let _ = std::fs::remove_file(path);
        }
        let listener = UnixListener::bind(path).map_err(|e| {
            Error::app(
                ErrorCode::Unavailable,
                format!("bind {}: {e}", path.display()),
            )
        })?;
        info!(path = %path.display(), "Client Protocol listening");

        loop {
            let (stream, _) = listener.accept().await.map_err(|e| {
                Error::app(ErrorCode::Unavailable, format!("accept: {e}"))
            })?;
            let store = self.store.clone();
            tokio::spawn(async move {
                if let Err(e) = handle_client(stream, store).await {
                    warn!(error = %e, "client session ended");
                }
            });
        }
    }
}

async fn handle_client(mut stream: UnixStream, store: Arc<Mutex<ItemStore>>) -> Result<()> {
    let mut decoder = FrameDecoder::new();
    let mut tmp = [0u8; 8192];
    loop {
        let n = stream.read(&mut tmp).await?;
        if n == 0 {
            return Ok(());
        }
        decoder.push(&tmp[..n]);
        while let Some(frame) = decoder.next_frame()? {
            let req: Value = serde_json::from_slice(&frame)?;
            let id = req.get("id").cloned().unwrap_or(Value::Null);
            let method = req.get("method").and_then(|m| m.as_str()).unwrap_or("");
            let params = req.get("params").cloned().unwrap_or(json!({}));

            let response = match method {
                "items/list" => {
                    let instance = params
                        .get("providerInstanceId")
                        .and_then(|v| v.as_str())
                        .unwrap_or("");
                    let items = store
                        .lock()
                        .expect("store")
                        .list_by_instance(instance)?;
                    json!({ "jsonrpc": "2.0", "id": id, "result": { "items": items } })
                }
                "items/get" => {
                    let pid = params
                        .get("id")
                        .and_then(|v| v.get("providerInstanceId"))
                        .and_then(|v| v.as_str())
                        .unwrap_or("");
                    let lid = params
                        .get("id")
                        .and_then(|v| v.get("localId"))
                        .and_then(|v| v.as_str())
                        .unwrap_or("");
                    let item = store
                        .lock()
                        .expect("store")
                        .get(&ItemId::new(pid, lid))?;
                    json!({ "jsonrpc": "2.0", "id": id, "result": { "item": item } })
                }
                "ping" => json!({ "jsonrpc": "2.0", "id": id, "result": { "ok": true } }),
                "" => json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "error": { "code": ErrorCode::InvalidRequest.as_i32(), "message": "InvalidRequest" }
                }),
                other => json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "error": {
                        "code": ErrorCode::MethodNotFound.as_i32(),
                        "message": format!("MethodNotFound: {other}")
                    }
                }),
            };
            let body = serde_json::to_vec(&response)?;
            stream.write_all(&encode_frame(&body)).await?;
            stream.flush().await?;
        }
    }
}
