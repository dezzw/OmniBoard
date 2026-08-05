//! In-process EventBus (docs/architecture/06-event-system.md).

use std::sync::{Arc, Mutex};

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Event {
    pub id: String,
    #[serde(rename = "type")]
    pub event_type: String,
    pub ts: DateTime<Utc>,
    pub source: EventSource,
    pub payload: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EventSource {
    pub kind: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub provider_instance_id: Option<String>,
}

pub type Subscriber = Arc<dyn Fn(&Event) + Send + Sync>;

#[derive(Default)]
pub struct EventBus {
    subs: Mutex<Vec<(Option<String>, Subscriber)>>,
}

impl EventBus {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn subscribe(&self, type_filter: Option<String>, cb: Subscriber) {
        self.subs.lock().expect("event bus lock").push((type_filter, cb));
    }

    pub fn emit(&self, event_type: impl Into<String>, source: EventSource, payload: Value) -> Event {
        let event = Event {
            id: format!("evt_{}", Uuid::new_v4()),
            event_type: event_type.into(),
            ts: Utc::now(),
            source,
            payload,
        };
        let subs = self.subs.lock().expect("event bus lock");
        for (filter, cb) in subs.iter() {
            if filter.as_ref().is_none_or(|f| f == &event.event_type) {
                cb(&event);
            }
        }
        event
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::sync::atomic::{AtomicUsize, Ordering};

    #[test]
    fn fans_out_filtered() {
        let bus = EventBus::new();
        let hits = Arc::new(AtomicUsize::new(0));
        let h = hits.clone();
        bus.subscribe(
            Some("item.changed".into()),
            Arc::new(move |_| {
                h.fetch_add(1, Ordering::SeqCst);
            }),
        );
        bus.emit(
            "item.changed",
            EventSource {
                kind: "provider".into(),
                provider_instance_id: Some("inst".into()),
            },
            json!({}),
        );
        bus.emit(
            "provider.status",
            EventSource {
                kind: "provider".into(),
                provider_instance_id: Some("inst".into()),
            },
            json!({}),
        );
        assert_eq!(hits.load(Ordering::SeqCst), 1);
    }
}
