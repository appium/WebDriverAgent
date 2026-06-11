# mobilerun/audiocapture

Opus audio streaming over a TCP socket, controlled by REST. The audio source is the
ReplayKit broadcast extension's **app audio** (see
[broadcast-extension.md](broadcast-extension.md)); microphone audio is not captured.

Source: [`FBAudioCaptureCommands.m`](../WebDriverAgentLib/Commands/FBAudioCaptureCommands.m),
[`FBAudioStreamManager.m`](../WebDriverAgentLib/Utilities/FBAudioStreamManager.m),
[`FBAudioStreamSession.m`](../WebDriverAgentLib/Utilities/FBAudioStreamSession.m),
[`FBExtAudioPipeline.m`](../WebDriverAgentBroadcast/FBExtAudioPipeline.m).

## Model

Two transports are involved, mirroring [mobilerun-screencapture.md](mobilerun-screencapture.md):

- **Control** — REST over WDA's HTTP server (the usual WDA port, e.g. `8100`).
- **Audio** — a separate **raw TCP socket** per session. WDA binds a TCP port and *broadcasts*
  the encoded stream to every connected client.

Unlike video there is **no fallback source**: Opus packets only flow while a ReplayKit
broadcast is running (`POST /mobilerun/screencapture/broadcast/start`, or started manually
from Control Center). Creating a session always succeeds; without a broadcast it simply sends
no bytes and reports `"streaming": false`. ReplayKit broadcasts require a **physical iOS
device**.

Encoding happens inside the broadcast extension with AudioToolbox's `AudioConverter`
(`kAudioFormatOpus`): the incoming app audio (typically 44.1 kHz) is resampled to **48 kHz**
and packetized as one Opus packet per **20 ms** (960 samples).

All routes exist in **session-scoped** and **`.withoutSession`** variants.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/mobilerun/audiocapture/start` | Start a new stream; returns the session object (incl. the TCP `port`). |
| `GET`  | `/mobilerun/audiocapture` | List active sessions: `{ "sessions": [ {…}, … ] }`. |
| `GET`  | `/mobilerun/audiocapture/:id` | Get one session object (or `null`). |
| `POST` | `/mobilerun/audiocapture/:id/stop` | Stop one session. |
| `POST` | `/mobilerun/audiocapture/stop` | Stop **all** sessions. |

There is no keyframe endpoint — every Opus packet is independently decodable.

## Start arguments (JSON body)

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `codec` | string | no | `"opus"` | Only `opus` is supported. |
| `framing` | string | no | `"raw"` | `raw`/`bare`, or `scrcpy`/`packet`/`packetized`. See [Wire formats](#wire-formats). |
| `bitrate` | int | no | `128000` | Target average bits/sec. |
| `channels` | int | no | `2` | `1` or `2`. |
| `port` | int | no | auto | `0` or omitted → auto-assign from **9400** (env `AUDIO_CAPTURE_SERVER_PORT` overrides the base), scanning forward up to 64 ports. An explicit port (1–65535) is tried once and surfaces a bind failure. |

## Session object

Returned by `start` and `GET …/:id`; also the array items of the list response.

```json
{
  "id": 1,
  "codec": "opus",
  "framing": "raw",
  "sampleRate": 48000,
  "channels": 2,
  "bitrate": 128000,
  "port": 9400,
  "clients": 0,
  "streaming": false,
  "source": "none",
  "packetsReceived": 0,
  "lastPacketAtMs": null,
  "lastError": null
}
```

- `streaming` / `source` — `true` / `"replaykit"` while broadcast packets are arriving;
  `false` / `"none"` before the first packet, after the extension disconnects or after an
  extension-side error.
- `lastError` — the extension's failure message when the audio pipeline could not be created
  (e.g. the Opus encoder is unavailable on the OS); cleared when a fresh `OpusHead` arrives.

## Wire formats

You pick this with `framing`. Both carry the same Opus packets; they differ only in how bytes
are laid out on the TCP socket.

### `raw` (default)

Bare Opus packets written back-to-back.

- **Not self-delimiting** — Opus packets carry no length information, so the byte stream
  cannot be re-segmented after the fact. Only use this when the consumer treats the stream as
  opaque or can rely on TCP segment boundaries (which are **not** guaranteed). For anything
  that needs packet boundaries or timestamps, use `scrcpy`.
- No codec configuration is sent; the stream parameters are fixed (48 kHz, the session's
  `channels`).

### `scrcpy`

The scrcpy audio packet framing — identical to the video `scrcpy` framing in
[mobilerun-screencapture.md](mobilerun-screencapture.md) and to scrcpy's own
`Streamer.writeFrameMeta`. Per packet, **big-endian**:

```
[ 8 bytes: flags(top 2 bits) | PTS µs (low 62 bits) ] [ 4 bytes: payload size ] [ size bytes: payload ]
```

- bit 63 = **config** packet. The payload is the 19-byte RFC 7845 **`OpusHead`**
  identification header (what scrcpy sends as the Opus config packet and what FFmpeg expects
  as `extradata`). Sent immediately on connect and again whenever the parameters change.
  Config packets carry a zero pts, matching scrcpy.
- Data packets carry one Opus packet each with the presentation timestamp in **microseconds**
  in the low 62 bits (flags are zero). The pts is sample-accurate (derived from the encoder's
  sample count, 20 000 µs per packet), unlike scrcpy's wall-clock stamps.
- There is no 4-byte codec-id header at stream start (scrcpy's `sendCodecMeta`); like the
  video stream, the connection starts directly with packets.

## Examples

Start a session and the broadcast, then dump the stream:

```bash
curl -s -X POST http://localhost:8100/mobilerun/audiocapture/start \
  -H 'Content-Type: application/json' \
  -d '{"framing":"scrcpy","bitrate":128000}'
# → { "id":1, "framing":"scrcpy", "port":9400, "streaming":false, ... }

curl -s -X POST http://localhost:8100/mobilerun/screencapture/broadcast/start

nc <device-host> 9400 | xxd | head
# First 12+19 bytes: a config packet whose payload starts with "OpusHead"
# (4f 70 75 73 48 65 61 64), then ~50 data packets/second while audio plays.
```

Raw mode (e.g. for piping into a custom consumer):

```bash
curl -s -X POST http://localhost:8100/mobilerun/audiocapture/start -d '{"framing":"raw"}'
nc <device-host> 9400 > capture.opus   # bare packets, ~bitrate/8 bytes per second
```

Stop:

```bash
curl -s -X POST http://localhost:8100/mobilerun/audiocapture/1/stop
```

## Notes / gotchas

- The stream is **push-only**; any bytes a client sends are ignored. Slow clients are dropped
  rather than buffered (1 s write timeout), and `TCP_NODELAY` is on for low latency.
- ffplay/ffmpeg cannot consume either framing directly (raw Opus packets are not
  self-delimiting and the scrcpy framing needs header stripping); parse the 12-byte headers
  and feed the packets to a decoder, or mux them into Ogg yourself.
- Pausing the broadcast (or a silent gap from ReplayKit) re-anchors the pts timeline; expect a
  pts jump rather than a run of silence-filled packets.
- Stopping the broadcast keeps sessions and their TCP clients alive; packets resume when the
  next broadcast starts. The OpusHead config packet is re-sent automatically when its
  parameters change.
- The broadcast status endpoint (`GET /mobilerun/screencapture/broadcast`) lists audio
  sessions under `audioSessions` and the extension heartbeat exposes per-pipeline counters
  under `audioPipelines`.
