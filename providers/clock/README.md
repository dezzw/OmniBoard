# Clock reference provider

Minimal OPP provider written in Python (stdlib only). Demonstrates that providers need not be OOP — a simple loop over framed JSON-RPC is enough.

```bash
nix develop -c python providers/clock/provider.py
```

Speak OPP on stdio with `Content-Length` framing. Emits `com.omniboard.clock.now` once per second.
