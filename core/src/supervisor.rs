//! ProviderSupervisor — spawn OPP providers over stdio and apply item updates.

use std::path::PathBuf;
use std::process::Stdio;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use serde_json::{json, Value};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::process::{Child, ChildStdin, ChildStdout, Command};
use tokio::sync::mpsc;
use tokio::time::timeout;
use tracing::{debug, info, warn};

use crate::error::{Error, ErrorCode, Result};
use crate::event::{EventBus, EventSource};
use crate::framing::{encode_frame, FrameDecoder};
use crate::opp::{
    negotiate_capabilities, InitializeParams, InitializeResult, ItemsChangedParams, JsonRpcRequest,
};
use crate::store::ItemStore;

const DEFAULT_INIT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug, Clone)]
pub struct SupervisorConfig {
    pub provider_instance_id: String,
    pub command: PathBuf,
    pub args: Vec<String>,
    pub env: Vec<(String, String)>,
    pub working_dir: Option<PathBuf>,
    pub config: Value,
    pub locale: Option<String>,
}

pub struct ProviderSupervisor {
    store: Arc<Mutex<ItemStore>>,
    bus: Arc<EventBus>,
}

impl ProviderSupervisor {
    pub fn new(store: Arc<Mutex<ItemStore>>, bus: Arc<EventBus>) -> Self {
        Self { store, bus }
    }

    /// Spawn the provider, complete OPP handshake, and process messages until exit.
    pub async fn run(&self, cfg: SupervisorConfig) -> Result<()> {
        self.emit_lifecycle("Stopped", "Starting", "user_start");

        let mut child = self.spawn(&cfg)?;
        let stdin = child.stdin.take().ok_or_else(|| {
            Error::app(ErrorCode::InternalError, "provider stdin missing")
        })?;
        let stdout = child.stdout.take().ok_or_else(|| {
            Error::app(ErrorCode::InternalError, "provider stdout missing")
        })?;

        let mut session = OppSession {
            stdin,
            stdout,
            decoder: FrameDecoder::new(),
            store: self.store.clone(),
            bus: self.bus.clone(),
            instance_id: cfg.provider_instance_id.clone(),
        };

        match session.handshake(&cfg).await {
            Ok(negotiated) => {
                info!(
                    instance = %cfg.provider_instance_id,
                    caps = %negotiated,
                    "OPP initialize complete"
                );
                self.emit_lifecycle("Starting", "Ready", "initialize_ok");
                self.emit_lifecycle("Ready", "Running", "handshake");
            }
            Err(e) => {
                let _ = child.kill().await;
                self.emit_lifecycle("Starting", "Failed", &e.to_string());
                return Err(e);
            }
        }

        let (stop_tx, mut stop_rx) = mpsc::channel::<()>(1);
        let wait_handle = tokio::spawn(async move {
            let status = child.wait().await;
            let _ = stop_tx.send(()).await;
            status
        });

        loop {
            tokio::select! {
                msg = session.read_message() => {
                    match msg {
                        Ok(value) => {
                            if let Err(e) = session.handle_incoming(value).await {
                                warn!(error = %e, "failed handling OPP message");
                            }
                        }
                        Err(e) => {
                            warn!(error = %e, "OPP read error");
                            break;
                        }
                    }
                }
                _ = stop_rx.recv() => {
                    break;
                }
            }
        }

        let status = wait_handle
            .await
            .map_err(|e| Error::app(ErrorCode::InternalError, e.to_string()))?
            .map_err(|e| Error::app(ErrorCode::ProviderCrash, e.to_string()))?;

        if status.success() {
            self.emit_lifecycle("Running", "Stopped", "clean_exit");
            Ok(())
        } else {
            self.emit_lifecycle("Running", "Failed", &format!("exit {status}"));
            Err(Error::app(
                ErrorCode::ProviderCrash,
                format!("provider exited with {status}"),
            ))
        }
    }

    fn spawn(&self, cfg: &SupervisorConfig) -> Result<Child> {
        let mut cmd = Command::new(&cfg.command);
        cmd.args(&cfg.args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .env("OMNIBOARD_INSTANCE_ID", &cfg.provider_instance_id)
            .env("OMNIBOARD_OPP_VERSION", "1.0")
            .env("OMNIBOARD_CHANNEL", "stdio")
            .kill_on_drop(true);
        for (k, v) in &cfg.env {
            cmd.env(k, v);
        }
        if let Some(dir) = &cfg.working_dir {
            cmd.current_dir(dir);
        }
        cmd.spawn().map_err(|e| {
            Error::app(
                ErrorCode::Unavailable,
                format!("failed to spawn {}: {e}", cfg.command.display()),
            )
        })
    }

    fn emit_lifecycle(&self, from: &str, to: &str, reason: &str) {
        self.bus.emit(
            "provider.lifecycle",
            EventSource {
                kind: "core".into(),
                provider_instance_id: None,
            },
            json!({ "from": from, "to": to, "reason": reason }),
        );
    }
}

struct OppSession {
    stdin: ChildStdin,
    stdout: ChildStdout,
    decoder: FrameDecoder,
    store: Arc<Mutex<ItemStore>>,
    bus: Arc<EventBus>,
    instance_id: String,
}

impl OppSession {
    async fn handshake(&mut self, cfg: &SupervisorConfig) -> Result<Value> {
        let core_caps = json!({
            "items": { "push": true, "pull": true },
            "actions": { "execute": true },
            "cache": { "hints": true },
            "encoding": ["json"]
        });

        let params = InitializeParams {
            opp_version: "1.0".into(),
            process_id: Some(std::process::id() as i64),
            client_info: Some(crate::opp::ClientInfo {
                name: "omniboard-core".into(),
                version: env!("CARGO_PKG_VERSION").into(),
            }),
            capabilities: core_caps.clone(),
            instance: crate::opp::InstanceInfo {
                provider_instance_id: cfg.provider_instance_id.clone(),
                config: cfg.config.clone(),
                locale: cfg.locale.clone(),
            },
        };

        let req = JsonRpcRequest {
            jsonrpc: "2.0".into(),
            id: json!(1),
            method: "initialize".into(),
            params: serde_json::to_value(params)?,
        };
        self.write_json(&req).await?;

        let response = timeout(DEFAULT_INIT_TIMEOUT, self.read_message())
            .await
            .map_err(|_| Error::app(ErrorCode::Timeout, "initialize timed out"))??;

        let result = response
            .get("result")
            .ok_or_else(|| Error::app(ErrorCode::InvalidRequest, "initialize missing result"))?;
        let init: InitializeResult = serde_json::from_value(result.clone())?;
        let negotiated = negotiate_capabilities(&core_caps, &init.capabilities);

        self.write_json(&json!({
            "jsonrpc": "2.0",
            "method": "initialized",
            "params": {}
        }))
        .await?;

        Ok(negotiated)
    }

    async fn write_json<T: serde::Serialize>(&mut self, msg: &T) -> Result<()> {
        let body = serde_json::to_vec(msg)?;
        let frame = encode_frame(&body);
        self.stdin.write_all(&frame).await?;
        self.stdin.flush().await?;
        Ok(())
    }

    async fn read_message(&mut self) -> Result<Value> {
        let mut tmp = [0u8; 8192];
        loop {
            if let Some(frame) = self.decoder.next_frame()? {
                return Ok(serde_json::from_slice(&frame)?);
            }
            let n = self.stdout.read(&mut tmp).await?;
            if n == 0 {
                return Err(Error::app(
                    ErrorCode::Unavailable,
                    "provider stdout closed",
                ));
            }
            self.decoder.push(&tmp[..n]);
        }
    }

    async fn handle_incoming(&mut self, msg: Value) -> Result<()> {
        let method = msg.get("method").and_then(|m| m.as_str());
        match method {
            Some("items/changed") => self.on_items_changed(msg).await,
            Some("provider/status") => {
                let params = msg.get("params").cloned().unwrap_or(json!({}));
                self.bus.emit(
                    "provider.status",
                    EventSource {
                        kind: "provider".into(),
                        provider_instance_id: Some(self.instance_id.clone()),
                    },
                    params,
                );
                Ok(())
            }
            Some("log") => {
                debug!(target: "provider", ?msg, "provider log");
                Ok(())
            }
            Some(other) if msg.get("id").is_some() => {
                // Unhandled request — reply method not found
                let id = msg.get("id").cloned().unwrap_or(Value::Null);
                self.write_json(&json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "error": {
                        "code": ErrorCode::MethodNotFound.as_i32(),
                        "message": format!("MethodNotFound: {other}")
                    }
                }))
                .await
            }
            Some(_) | None => {
                debug!(?msg, "ignored OPP message");
                Ok(())
            }
        }
    }

    async fn on_items_changed(&mut self, msg: Value) -> Result<()> {
        let params: ItemsChangedParams = serde_json::from_value(
            msg.get("params")
                .cloned()
                .ok_or_else(|| Error::app(ErrorCode::InvalidParams, "items/changed missing params"))?,
        )?;

        if params.provider_instance_id != self.instance_id {
            return Err(Error::app(
                ErrorCode::InvalidParams,
                "providerInstanceId mismatch",
            ));
        }

        let store = self.store.lock().expect("store lock");

        if let Some(snapshot) = params.snapshot {
            store.replace_snapshot(&params.provider_instance_id, &snapshot.items)?;
            self.bus.emit(
                "items.snapshotApplied",
                EventSource {
                    kind: "provider".into(),
                    provider_instance_id: Some(self.instance_id.clone()),
                },
                json!({
                    "providerInstanceId": self.instance_id,
                    "count": snapshot.items.len()
                }),
            );
            return Ok(());
        }

        if let Some(delta) = params.delta {
            for item in &delta.upsert {
                let applied = store.upsert(item)?;
                if applied {
                    self.bus.emit(
                        "item.changed",
                        EventSource {
                            kind: "provider".into(),
                            provider_instance_id: Some(self.instance_id.clone()),
                        },
                        json!({
                            "id": item.id,
                            "revision": item.revision,
                            "type": item.item_type
                        }),
                    );
                }
            }
            for id in &delta.delete {
                if store.delete(id)? {
                    self.bus.emit(
                        "item.deleted",
                        EventSource {
                            kind: "provider".into(),
                            provider_instance_id: Some(self.instance_id.clone()),
                        },
                        json!({ "id": id }),
                    );
                }
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::process::{Command as StdCommand, Stdio as StdStdio};

    #[tokio::test]
    async fn supervisor_applies_clock_items() {
        let store = Arc::new(Mutex::new(ItemStore::open_in_memory().unwrap()));
        let bus = Arc::new(EventBus::new());
        let hits = Arc::new(Mutex::new(0u32));
        let h = hits.clone();
        bus.subscribe(
            Some("item.changed".into()),
            Arc::new(move |_| {
                *h.lock().unwrap() += 1;
            }),
        );

        // Tiny fake provider script via python -c if available, else skip.
        let py = which_python();
        let Some(py) = py else {
            eprintln!("skip: no python");
            return;
        };

        let script = r#"
import json,sys,os
def r():
  h={}
  while True:
    l=sys.stdin.buffer.readline()
    if l in (b'\r\n',b'\n'): break
    k,_,v=l.decode().partition(':'); h[k.strip().lower()]=v.strip()
  n=int(h['content-length']); return json.loads(sys.stdin.buffer.read(n))
def w(o):
  b=json.dumps(o).encode(); sys.stdout.buffer.write(f'Content-Length: {len(b)}\r\n\r\n'.encode()+b); sys.stdout.buffer.flush()
req=r(); w({'jsonrpc':'2.0','id':req['id'],'result':{'oppVersion':'1.0','serverInfo':{'name':'t','version':'0'},'capabilities':{'items':{'push':True,'pull':False},'encoding':['json']}}})
_ = r()
w({'jsonrpc':'2.0','method':'provider/status','params':{'state':'ready'}})
inst=os.environ['OMNIBOARD_INSTANCE_ID']
w({'jsonrpc':'2.0','method':'items/changed','params':{'providerInstanceId':inst,'delta':{'upsert':[{'id':{'providerInstanceId':inst,'localId':'x'},'type':'com.test.x','revision':1,'updatedAt':'2026-08-04T20:00:00Z','payload':{'n':1},'render':{'schemaVersion':'1.0','root':{'type':'Text','value':'ok'}}}],'delete':[]}}})
"#;

        let supervisor = ProviderSupervisor::new(store.clone(), bus);
        let cfg = SupervisorConfig {
            provider_instance_id: "inst_test".into(),
            command: PathBuf::from(&py),
            args: vec!["-c".into(), script.into()],
            env: vec![],
            working_dir: None,
            config: json!({}),
            locale: Some("en-US".into()),
        };

        // Run until provider exits (after one item).
        let result = timeout(Duration::from_secs(5), supervisor.run(cfg)).await;
        assert!(result.is_ok(), "supervisor timed out or failed: {result:?}");

        let item = store
            .lock()
            .unwrap()
            .get(&crate::item::ItemId::new("inst_test", "x"))
            .unwrap();
        assert!(item.is_some());
        assert!(*hits.lock().unwrap() >= 1);
    }

    fn which_python() -> Option<String> {
        for name in ["python3", "python"] {
            if StdCommand::new(name)
                .arg("-c")
                .arg("print(1)")
                .stdout(StdStdio::null())
                .stderr(StdStdio::null())
                .status()
                .map(|s| s.success())
                .unwrap_or(false)
            {
                return Some(name.into());
            }
        }
        None
    }
}
