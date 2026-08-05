//! OPP message types and capability negotiation helpers.

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::item::{Item, ItemId};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcRequest {
    pub jsonrpc: String,
    pub id: Value,
    pub method: String,
    #[serde(default)]
    pub params: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcNotification {
    pub jsonrpc: String,
    pub method: String,
    #[serde(default)]
    pub params: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcSuccess {
    pub jsonrpc: String,
    pub id: Value,
    pub result: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcFailure {
    pub jsonrpc: String,
    pub id: Value,
    pub error: JsonRpcErrorBody,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonRpcErrorBody {
    pub code: i32,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InitializeParams {
    pub opp_version: String,
    #[serde(default)]
    pub process_id: Option<i64>,
    #[serde(default)]
    pub client_info: Option<ClientInfo>,
    pub capabilities: Value,
    pub instance: InstanceInfo,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClientInfo {
    pub name: String,
    pub version: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InstanceInfo {
    pub provider_instance_id: String,
    #[serde(default)]
    pub config: Value,
    #[serde(default)]
    pub locale: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InitializeResult {
    pub opp_version: String,
    pub server_info: ClientInfo,
    pub capabilities: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ItemsChangedParams {
    pub provider_instance_id: String,
    #[serde(default)]
    pub delta: Option<ItemDelta>,
    #[serde(default)]
    pub snapshot: Option<ItemSnapshot>,
    #[serde(default)]
    pub cache: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ItemDelta {
    #[serde(default)]
    pub upsert: Vec<Item>,
    #[serde(default)]
    pub delete: Vec<ItemId>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ItemSnapshot {
    pub items: Vec<Item>,
}

/// Intersect boolean capabilities under common OPP keys.
pub fn negotiate_capabilities(core: &Value, provider: &Value) -> Value {
    let mut out = serde_json::Map::new();
    if let (Some(c), Some(p)) = (core.as_object(), provider.as_object()) {
        for (k, cv) in c {
            if let Some(pv) = p.get(k) {
                out.insert(k.clone(), intersect_value(cv, pv));
            }
        }
    }
    Value::Object(out)
}

fn intersect_value(a: &Value, b: &Value) -> Value {
    match (a, b) {
        (Value::Bool(x), Value::Bool(y)) => Value::Bool(*x && *y),
        (Value::Object(ao), Value::Object(bo)) => {
            let mut m = serde_json::Map::new();
            for (k, av) in ao {
                if let Some(bv) = bo.get(k) {
                    m.insert(k.clone(), intersect_value(av, bv));
                }
            }
            Value::Object(m)
        }
        (Value::Array(aa), Value::Array(ba)) => {
            let set: Vec<Value> = aa
                .iter()
                .filter(|v| ba.contains(v))
                .cloned()
                .collect();
            Value::Array(set)
        }
        _ => b.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn capability_intersection() {
        let core = json!({
            "items": {"push": true, "pull": true},
            "encoding": ["json", "msgpack"]
        });
        let provider = json!({
            "items": {"push": true, "pull": false},
            "encoding": ["json"]
        });
        let n = negotiate_capabilities(&core, &provider);
        assert_eq!(n["items"]["push"], json!(true));
        assert_eq!(n["items"]["pull"], json!(false));
        assert_eq!(n["encoding"], json!(["json"]));
    }
}
