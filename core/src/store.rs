//! SQLite ItemStore — local source of truth.

use std::path::Path;

use rusqlite::{params, Connection, OptionalExtension};

use crate::error::{Error, ErrorCode, Result};
use crate::item::{Item, ItemId};
use crate::render::validate_render;

pub struct ItemStore {
    conn: Connection,
}

impl ItemStore {
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        let conn = Connection::open(path)?;
        let store = Self { conn };
        store.migrate()?;
        Ok(store)
    }

    pub fn open_in_memory() -> Result<Self> {
        let conn = Connection::open_in_memory()?;
        let store = Self { conn };
        store.migrate()?;
        Ok(store)
    }

    fn migrate(&self) -> Result<()> {
        self.conn.execute_batch(
            r#"
            CREATE TABLE IF NOT EXISTS items (
              provider_instance_id TEXT NOT NULL,
              local_id TEXT NOT NULL,
              item_type TEXT NOT NULL,
              revision INTEGER NOT NULL,
              updated_at TEXT NOT NULL,
              payload TEXT NOT NULL,
              render TEXT,
              actions TEXT NOT NULL DEFAULT '[]',
              tags TEXT NOT NULL DEFAULT '[]',
              ttl TEXT,
              priority INTEGER,
              as_of TEXT,
              stale_after TEXT,
              PRIMARY KEY (provider_instance_id, local_id)
            );
            CREATE INDEX IF NOT EXISTS idx_items_type ON items(item_type);
            "#,
        )?;
        Ok(())
    }

    /// Upsert if incoming revision is strictly greater than stored.
    /// Returns true if applied.
    pub fn upsert(&self, item: &Item) -> Result<bool> {
        if let Some(render) = &item.render {
            validate_render(render).map_err(|m| Error::app(ErrorCode::InvalidRender, m))?;
        }

        let existing: Option<u64> = self
            .conn
            .query_row(
                "SELECT revision FROM items WHERE provider_instance_id = ?1 AND local_id = ?2",
                params![item.id.provider_instance_id, item.id.local_id],
                |row| row.get(0),
            )
            .optional()?;

        if let Some(rev) = existing {
            if item.revision <= rev {
                return Ok(false);
            }
        }

        let payload = serde_json::to_string(&item.payload)?;
        let render = item
            .render
            .as_ref()
            .map(serde_json::to_string)
            .transpose()?;
        let actions = serde_json::to_string(&item.actions)?;
        let tags = serde_json::to_string(&item.tags)?;

        self.conn.execute(
            r#"
            INSERT INTO items (
              provider_instance_id, local_id, item_type, revision, updated_at,
              payload, render, actions, tags, ttl, priority, as_of, stale_after
            ) VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13)
            ON CONFLICT(provider_instance_id, local_id) DO UPDATE SET
              item_type=excluded.item_type,
              revision=excluded.revision,
              updated_at=excluded.updated_at,
              payload=excluded.payload,
              render=excluded.render,
              actions=excluded.actions,
              tags=excluded.tags,
              ttl=excluded.ttl,
              priority=excluded.priority,
              as_of=excluded.as_of,
              stale_after=excluded.stale_after
            "#,
            params![
                item.id.provider_instance_id,
                item.id.local_id,
                item.item_type,
                item.revision as i64,
                item.updated_at.to_rfc3339(),
                payload,
                render,
                actions,
                tags,
                item.ttl,
                item.priority,
                item.as_of.map(|t| t.to_rfc3339()),
                item.stale_after.map(|t| t.to_rfc3339()),
            ],
        )?;
        Ok(true)
    }

    pub fn delete(&self, id: &ItemId) -> Result<bool> {
        let n = self.conn.execute(
            "DELETE FROM items WHERE provider_instance_id = ?1 AND local_id = ?2",
            params![id.provider_instance_id, id.local_id],
        )?;
        Ok(n > 0)
    }

    pub fn get(&self, id: &ItemId) -> Result<Option<Item>> {
        self.conn
            .query_row(
                "SELECT provider_instance_id, local_id, item_type, revision, updated_at, payload, render, actions, tags, ttl, priority, as_of, stale_after
                 FROM items WHERE provider_instance_id = ?1 AND local_id = ?2",
                params![id.provider_instance_id, id.local_id],
                row_to_item,
            )
            .optional()
            .map_err(Into::into)
    }

    pub fn list_by_instance(&self, provider_instance_id: &str) -> Result<Vec<Item>> {
        let mut stmt = self.conn.prepare(
            "SELECT provider_instance_id, local_id, item_type, revision, updated_at, payload, render, actions, tags, ttl, priority, as_of, stale_after
             FROM items WHERE provider_instance_id = ?1 ORDER BY priority DESC NULLS LAST, updated_at DESC",
        )?;
        let rows = stmt.query_map(params![provider_instance_id], row_to_item)?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row?);
        }
        Ok(out)
    }

    pub fn replace_snapshot(&self, provider_instance_id: &str, items: &[Item]) -> Result<()> {
        for item in items {
            if item.id.provider_instance_id != provider_instance_id {
                return Err(Error::app(
                    ErrorCode::InvalidParams,
                    "snapshot item instance mismatch",
                ));
            }
            if let Some(render) = &item.render {
                validate_render(render).map_err(|m| Error::app(ErrorCode::InvalidRender, m))?;
            }
        }

        let tx = self.conn.unchecked_transaction()?;
        tx.execute(
            "DELETE FROM items WHERE provider_instance_id = ?1",
            params![provider_instance_id],
        )?;
        for item in items {
            let payload = serde_json::to_string(&item.payload)?;
            let render = item
                .render
                .as_ref()
                .map(serde_json::to_string)
                .transpose()?;
            let actions = serde_json::to_string(&item.actions)?;
            let tags = serde_json::to_string(&item.tags)?;
            tx.execute(
                r#"
                INSERT INTO items (
                  provider_instance_id, local_id, item_type, revision, updated_at,
                  payload, render, actions, tags, ttl, priority, as_of, stale_after
                ) VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13)
                "#,
                params![
                    item.id.provider_instance_id,
                    item.id.local_id,
                    item.item_type,
                    item.revision as i64,
                    item.updated_at.to_rfc3339(),
                    payload,
                    render,
                    actions,
                    tags,
                    item.ttl,
                    item.priority,
                    item.as_of.map(|t| t.to_rfc3339()),
                    item.stale_after.map(|t| t.to_rfc3339()),
                ],
            )?;
        }
        tx.commit()?;
        Ok(())
    }
}

fn row_to_item(row: &rusqlite::Row<'_>) -> rusqlite::Result<Item> {
    let updated_at: String = row.get(4)?;
    let payload: String = row.get(5)?;
    let render: Option<String> = row.get(6)?;
    let actions: String = row.get(7)?;
    let tags: String = row.get(8)?;
    let as_of: Option<String> = row.get(11)?;
    let stale_after: Option<String> = row.get(12)?;

    Ok(Item {
        id: ItemId {
            provider_instance_id: row.get(0)?,
            local_id: row.get(1)?,
        },
        item_type: row.get(2)?,
        revision: row.get::<_, i64>(3)? as u64,
        updated_at: chrono::DateTime::parse_from_rfc3339(&updated_at)
            .map(|d| d.with_timezone(&chrono::Utc))
            .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?,
        payload: serde_json::from_str(&payload)
            .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?,
        render: render
            .map(|s| serde_json::from_str(&s))
            .transpose()
            .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?,
        actions: serde_json::from_str(&actions)
            .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?,
        tags: serde_json::from_str(&tags)
            .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?,
        ttl: row.get(9)?,
        priority: row.get(10)?,
        as_of: as_of
            .map(|s| {
                chrono::DateTime::parse_from_rfc3339(&s).map(|d| d.with_timezone(&chrono::Utc))
            })
            .transpose()
            .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?,
        stale_after: stale_after
            .map(|s| {
                chrono::DateTime::parse_from_rfc3339(&s).map(|d| d.with_timezone(&chrono::Utc))
            })
            .transpose()
            .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;
    use serde_json::json;

    fn sample(rev: u64) -> Item {
        Item {
            id: ItemId::new("inst_clock", "now"),
            item_type: "com.omniboard.clock.now".into(),
            revision: rev,
            updated_at: Utc::now(),
            payload: json!({"unix": 1}),
            render: Some(crate::render::RenderDocument {
                schema_version: "1.0".into(),
                surface_hints: vec!["menuBar".into()],
                localization: None,
                root: json!({"type": "Text", "value": "now"}),
            }),
            actions: vec![],
            tags: vec!["demo".into()],
            ttl: None,
            priority: Some(1),
            as_of: None,
            stale_after: None,
        }
    }

    #[test]
    fn upsert_respects_monotonic_revision() {
        let store = ItemStore::open_in_memory().unwrap();
        assert!(store.upsert(&sample(1)).unwrap());
        assert!(!store.upsert(&sample(1)).unwrap());
        assert!(store.upsert(&sample(2)).unwrap());
        let got = store.get(&ItemId::new("inst_clock", "now")).unwrap().unwrap();
        assert_eq!(got.revision, 2);
    }
}
