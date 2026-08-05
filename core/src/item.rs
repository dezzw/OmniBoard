//! Item and ItemId types (docs/architecture/04-data-model.md).

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::render::RenderDocument;

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ItemId {
    pub provider_instance_id: String,
    pub local_id: String,
}

impl ItemId {
    pub fn new(provider_instance_id: impl Into<String>, local_id: impl Into<String>) -> Self {
        Self {
            provider_instance_id: provider_instance_id.into(),
            local_id: local_id.into(),
        }
    }

    pub fn canonical(&self) -> String {
        format!("{}:{}", self.provider_instance_id, self.local_id)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Item {
    pub id: ItemId,
    #[serde(rename = "type")]
    pub item_type: String,
    pub revision: u64,
    pub updated_at: DateTime<Utc>,
    pub payload: Value,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub render: Option<RenderDocument>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub actions: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ttl: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub priority: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub as_of: Option<DateTime<Utc>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stale_after: Option<DateTime<Utc>>,
}
