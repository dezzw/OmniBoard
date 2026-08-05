//! LSP-style Content-Length framing for OPP / Client Protocol (docs/architecture/09-ipc-protocol.md).

use std::io::{self, Read, Write};

use bytes::BytesMut;

use crate::error::{Error, ErrorCode, Result};

const HEADER_SEP: &[u8] = b"\r\n\r\n";

/// Encode a JSON (or other) body as a Content-Length frame.
pub fn encode_frame(body: &[u8]) -> Vec<u8> {
    let header = format!("Content-Length: {}\r\n\r\n", body.len());
    let mut out = Vec::with_capacity(header.len() + body.len());
    out.extend_from_slice(header.as_bytes());
    out.extend_from_slice(body);
    out
}

/// Incremental frame decoder.
#[derive(Debug, Default)]
pub struct FrameDecoder {
    buf: BytesMut,
}

impl FrameDecoder {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn push(&mut self, data: &[u8]) {
        self.buf.extend_from_slice(data);
    }

    /// Returns the next complete body, if available.
    pub fn next_frame(&mut self) -> Result<Option<Vec<u8>>> {
        let Some(header_end) = find_subslice(&self.buf, HEADER_SEP) else {
            return Ok(None);
        };
        let header = std::str::from_utf8(&self.buf[..header_end]).map_err(|_| {
            Error::app(ErrorCode::ParseError, "frame header is not valid UTF-8")
        })?;
        let mut content_length: Option<usize> = None;
        for line in header.split("\r\n") {
            let lower = line.to_ascii_lowercase();
            if let Some(rest) = lower.strip_prefix("content-length:") {
                content_length = rest.trim().parse().ok();
            }
        }
        let len = content_length.ok_or_else(|| {
            Error::app(ErrorCode::ParseError, "Content-Length header missing")
        })?;
        let body_start = header_end + HEADER_SEP.len();
        let body_end = body_start + len;
        if self.buf.len() < body_end {
            return Ok(None);
        }
        let body = self.buf[body_start..body_end].to_vec();
        let _ = self.buf.split_to(body_end);
        Ok(Some(body))
    }
}

fn find_subslice(hay: &[u8], needle: &[u8]) -> Option<usize> {
    hay.windows(needle.len()).position(|w| w == needle)
}

pub fn write_frame<W: Write>(w: &mut W, body: &[u8]) -> io::Result<()> {
    w.write_all(&encode_frame(body))?;
    w.flush()?;
    Ok(())
}

pub fn read_frame<R: Read>(r: &mut R, decoder: &mut FrameDecoder) -> Result<Vec<u8>> {
    let mut tmp = [0u8; 4096];
    loop {
        if let Some(frame) = decoder.next_frame()? {
            return Ok(frame);
        }
        let n = r.read(&mut tmp)?;
        if n == 0 {
            return Err(Error::app(
                ErrorCode::Unavailable,
                "EOF while reading OPP frame",
            ));
        }
        decoder.push(&tmp[..n]);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip_json() {
        let body = br#"{"jsonrpc":"2.0","method":"initialized"}"#;
        let framed = encode_frame(body);
        let mut dec = FrameDecoder::new();
        dec.push(&framed);
        let got = dec.next_frame().unwrap().unwrap();
        assert_eq!(got, body);
    }

    #[test]
    fn split_across_chunks() {
        let body = br#"{"a":1}"#;
        let framed = encode_frame(body);
        let mid = framed.len() / 2;
        let mut dec = FrameDecoder::new();
        dec.push(&framed[..mid]);
        assert!(dec.next_frame().unwrap().is_none());
        dec.push(&framed[mid..]);
        assert_eq!(dec.next_frame().unwrap().unwrap(), body);
    }
}
