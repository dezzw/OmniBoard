//! Render IR document (docs/architecture/05-rendering-schema.md).

use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RenderDocument {
    pub schema_version: String,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub surface_hints: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub localization: Option<Value>,
    pub root: Value,
}

/// Soft-validate a RenderDocument: require schemaVersion + root.type.
/// Unknown node types are allowed (degrade at render time).
pub fn validate_render(doc: &RenderDocument) -> Result<(), String> {
    if doc.schema_version.is_empty() {
        return Err("schemaVersion required".into());
    }
    let ty = doc
        .root
        .get("type")
        .and_then(|v| v.as_str())
        .ok_or_else(|| "root.type required".to_string())?;
    if ty.is_empty() {
        return Err("root.type empty".into());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn accepts_minimal_text() {
        let doc = RenderDocument {
            schema_version: "1.0".into(),
            surface_hints: vec![],
            localization: None,
            root: json!({"type": "Text", "value": "hi"}),
        };
        assert!(validate_render(&doc).is_ok());
    }
}
