# mobilerun/screencapture

H.264 / H.265 screen-capture streaming over a TCP socket, controlled by REST.
For audio see [mobilerun-audiocapture.md](mobilerun-audiocapture.md).

Source: [`FBScreenCaptureCommands.m`](../WebDriverAgentLib/Commands/FBScreenCaptureCommands.m),
[`FBVideoStreamManager.m`](../WebDriverAgentLib/Utilities/FBVideoStreamManager.m),
[`FBVideoStreamSession.m`](../WebDriverAgentLib/Utilities/FBVideoStreamSession.m).

## Model

Two transports are involved:

- **Control** — REST over WDA's HTTP server (the usual WDA port, e.g. `8100`). You start/stop/list
  sessions here.
- **Video** — a separate **raw TCP socket** per session. WDA binds a TCP port and *broadcasts* the
  encoded stream to every connected client. You connect a TCP client to `<device-host>:<port>` and
  read bytes.

Each session is an independent encoder + broadcaster with a numeric `id`. Multiple sessions can run
at once (different codec / resolution / fps), all fed from one shared screen-capture loop.

All routes exist in **session-scoped** and **`.withoutSession`** variants, so they work whether or
not a WDA automation session is active.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/mobilerun/screencapture/start` | Start a new stream; returns the session object (incl. the TCP `port`). |
| `GET`  | `/mobilerun/screencapture` | List active sessions: `{ "sessions": [ {…}, … ] }`. |
| `GET`  | `/mobilerun/screencapture/:id` | Get one session object (or `null`). |
| `POST` | `/mobilerun/screencapture/:id/stop` | Stop one session. |
| `POST` | `/mobilerun/screencapture/stop` | Stop **all** sessions. |
| `POST` | `/mobilerun/screencapture/:id/keyframe` | Force an IDR key frame now (lets a late joiner resync). |

## Start arguments (JSON body)

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `width` | int | **yes** | — | Positive; rounded **down to even** (hardware encoders require it). |
| `height` | int | **yes** | — | Same as width. |
| `codec` | string | no | `"h264"` | `h264`/`avc` or `h265`/`hevc`. |
| `framing` | string | no | `"annexb"` | `annexb`/`annex-b`/`raw`, or `scrcpy`/`packet`/`packetized`. See [Wire formats](#wire-formats). |
| `bitrate` | int | no | `6000000` | Target average bits/sec. |
| `quality` | float | no | `0.8` | JPEG quality (`0.0`–`1.0`) used for XCTest screenshot capture before local H.264/H.265 encoding. Lower values can reduce screenshot capture/decode cost. Does not affect ReplayKit/broadcast-source frames. |
| `fps` | int | no | `30` | Capture/encode frame rate. |
| `port` | int | no | auto | `0` or omitted → auto-assign from **9200** (env `SCREEN_CAPTURE_SERVER_PORT` overrides the base), scanning forward up to 64 ports. An explicit port (1–65535) is tried once and surfaces a bind failure. |

## Session object

Returned by `start` and `GET …/:id`; also the array items of the list response.

```json
{
  "id": 1,
  "codec": "h264",
  "framing": "annexb",
  "width": 750,
  "height": 1334,
  "fps": 30,
  "bitrate": 6000000,
  "quality": 0.8,
  "port": 9200,
  "clients": 0
}
```

## Wire formats

You pick this with `framing`. Both carry the same codec; they differ only in how bytes are laid out
on the TCP socket.

### `annexb` (default)

A raw Annex-B elementary stream:

- Bare NAL units, each prefixed with the start code `00 00 00 01`.
- SPS/PPS (+ VPS for HEVC) are **prepended to every key frame**, so each IDR is self-decodable.
- On connect, the latest parameter sets are pushed immediately and a key frame is forced.
- No timestamps or frame boundaries — the reader scans start codes and feeds a decoder.

### `scrcpy`

The scrcpy video packet framing (matches `ios-wired/cmd/scrcpy-bridge/h264reader.go`). Per packet,
**big-endian**:

```
[ 8 bytes: flags(top 2 bits) | PTS µs (low 62 bits) ] [ 4 bytes: payload size ] [ size bytes: Annex-B AU ]
```

- bit 63 = **config** packet (SPS/PPS, VPS for HEVC) — sent as its **own** packet (and on connect),
  not prepended to key frames.
- bit 62 = **key frame**.
- low 62 bits = presentation timestamp in **microseconds** (monotonic; consumers care about deltas).
- Config is emitted separately because the bridge caches it for new-peer init and re-prepends it to
  key frames itself.

## Examples

Start (raw, default), against `http://<device>:8100`:

```bash
curl -s -X POST http://localhost:8100/mobilerun/screencapture/start \
  -H 'Content-Type: application/json' \
  -d '{"width":750,"height":1334,"codec":"h264","fps":30,"quality":0.5}'
# → { "id":1, "framing":"annexb", "port":9200, ... }
```

Start the scrcpy-framed variant (for the `ios-wired` bridge):

```bash
curl -s -X POST http://localhost:8100/mobilerun/screencapture/start \
  -d '{"width":1170,"height":2532,"codec":"h264","framing":"scrcpy"}'
```

Consume the video and decode with ffmpeg (annexb mode — pipe the raw elementary stream straight in):

```bash
nc localhost 9200 | ffplay -f h264 -            # or -f hevc for h265
```

Force a key frame, then stop:

```bash
curl -s -X POST http://localhost:8100/mobilerun/screencapture/1/keyframe
curl -s -X POST http://localhost:8100/mobilerun/screencapture/1/stop
```

## Notes / gotchas

- `width`/`height` ≤ 0 → `400` invalid argument; same for an out-of-range `port` or an unknown
  `codec` / `framing` string (or a non-string value).
- The stream is **push-only**; any bytes a client sends are ignored. Slow clients are dropped rather
  than buffered (1 s write timeout), and `TCP_NODELAY` is on for low latency.
- A late joiner won't decode until the next key frame — hit the `/keyframe` endpoint (connecting
  already forces one) if you need an immediate resync.
- If multiple screenshot-source sessions request different `quality` values, WDA captures the
  shared local screenshot frame at the lowest requested quality and fans it out to all local
  encoders.
- For `scrcpy` framing you must parse the 12-byte header yourself (or reuse `ReadFrame` from
  `h264reader.go`); you can't pipe it straight into ffmpeg the way you can with `annexb`.
