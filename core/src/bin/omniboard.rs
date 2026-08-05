//! OmniBoard Core local daemon CLI.
//!
//! ```bash
//! nix develop -c cargo run -p omniboard-core --bin omniboard -- run \
//!   --provider-cmd python3 \
//!   --provider-arg providers/clock/provider.py \
//!   --socket /tmp/omniboard.sock \
//!   --db /tmp/omniboard.sqlite
//! ```

use std::path::PathBuf;
use std::sync::{Arc, Mutex};

use clap::{Parser, Subcommand};
use omniboard_core::client::ClientServer;
use omniboard_core::event::{EventBus, EventSource};
use omniboard_core::store::ItemStore;
use omniboard_core::supervisor::{ProviderSupervisor, SupervisorConfig};
use serde_json::json;
use tracing::info;
use tracing_subscriber::EnvFilter;

#[derive(Parser, Debug)]
#[command(name = "omniboard", about = "OmniBoard local Core")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Run Core: Client Protocol socket + one supervised provider.
    Run {
        /// SQLite database path
        #[arg(long, default_value = "omniboard.sqlite")]
        db: PathBuf,
        /// Unix socket for Client Protocol
        #[arg(long, default_value = "/tmp/omniboard.sock")]
        socket: PathBuf,
        /// Provider instance id
        #[arg(long, default_value = "inst_clock_1")]
        instance_id: String,
        /// Provider executable
        #[arg(long, default_value = "python3")]
        provider_cmd: PathBuf,
        /// Extra args for the provider (repeatable)
        #[arg(long = "provider-arg")]
        provider_args: Vec<String>,
        /// Working directory for the provider
        #[arg(long)]
        provider_cwd: Option<PathBuf>,
    },
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env().add_directive("info".parse()?))
        .init();

    let cli = Cli::parse();
    match cli.command {
        Commands::Run {
            db,
            socket,
            instance_id,
            provider_cmd,
            provider_args,
            provider_cwd,
        } => {
            let store = Arc::new(Mutex::new(ItemStore::open(&db)?));
            let bus = Arc::new(EventBus::new());
            bus.subscribe(
                None,
                Arc::new(|ev| {
                    info!(
                        target: "event",
                        r#type = %ev.event_type,
                        id = %ev.id,
                        "bus"
                    );
                }),
            );

            let client = ClientServer::new(store.clone(), bus.clone());
            let socket_path = socket.clone();
            tokio::spawn(async move {
                if let Err(e) = client.listen(socket_path).await {
                    eprintln!("client server error: {e}");
                }
            });

            // Give the listener a moment, then start provider.
            tokio::time::sleep(std::time::Duration::from_millis(50)).await;

            let supervisor = ProviderSupervisor::new(store.clone(), bus.clone());
            let cfg = SupervisorConfig {
                provider_instance_id: instance_id.clone(),
                command: provider_cmd,
                args: provider_args,
                env: vec![],
                working_dir: provider_cwd,
                config: json!({}),
                locale: Some("en-US".into()),
            };

            bus.emit(
                "core.started",
                EventSource {
                    kind: "core".into(),
                    provider_instance_id: None,
                },
                json!({
                    "db": db.display().to_string(),
                    "socket": socket.display().to_string(),
                    "instanceId": instance_id
                }),
            );

            supervisor.run(cfg).await?;
        }
    }
    Ok(())
}
