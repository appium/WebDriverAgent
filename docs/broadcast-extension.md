# ReplayKit Broadcast Extension

WebDriverAgent embeds a ReplayKit **broadcast upload extension**
(`WebDriverAgentBroadcast.appex`) into the generated
`WebDriverAgentRunner-Runner.app`. When a broadcast is running, the extension receives the
system's screen frames as pixel buffers (up to 60 fps, no polling), encodes them with one
hardware H.264/H.265 encoder per capture session and ships the elementary stream to WDA over
a loopback TCP connection. `/mobilerun/screencapture` sessions then serve those frames instead
of the XCTest screenshot loop, raising the achievable frame rate from ~10-20 fps to 30-60 fps.

The extension only works on **physical iOS devices** (ReplayKit broadcasts are unavailable on
the Simulator and tvOS). Without a running broadcast every capture session transparently uses
the legacy screenshot pipeline; each session reports its current origin via the `source` field
(`"replaykit"` or `"screenshot"`).

## HTTP endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/mobilerun/screencapture/broadcast/start` | POST | Starts a system broadcast targeting the bundled extension. Foregrounds the runner app, triggers `RPSystemBroadcastPickerView` and confirms the system sheet via UI automation, then waits for the extension to connect. Idempotent while connected. |
| `/mobilerun/screencapture/broadcast` | GET | Broadcast status: `state` (`idle`/`connected`/`paused`), control port, extension id, last heartbeat (frames received, orientation, screen size) and the capture sessions with their active `source`. |
| `/mobilerun/screencapture/broadcast/stop` | POST | Asks the extension to finish the broadcast. Live sessions fall back to the screenshot source with a forced key frame; clients do not need to reconnect. |

`broadcast/start` body (all optional):

```json
{
  "timeout": 30,
  "confirmButtonLabels": ["Start Broadcast"],
  "restoreForegroundApp": true
}
```

- `timeout` — seconds to wait for the extension to connect (covers the system's 3-2-1 countdown).
- `confirmButtonLabels` — labels to look for on the system confirmation sheet. Pass the
  localized label when the device language is not English (a button starting with "Start" is
  used as fallback).
- `restoreForegroundApp` — re-activate the previously active app after the broadcast starts
  (the start dance briefly foregrounds the runner app, ~2-3 s).

Notes:

- `/mobilerun/screencapture/start` never starts a broadcast by itself. Sessions started while
  the broadcast is connected attach to it automatically; sessions started before it pick it up
  on the extension's first key frame.
- Broadcasts started manually from Control Center attach exactly the same way (WDA listens
  permanently).
- If the broadcast stops (endpoint, status-bar pill, extension crash), sessions revert to the
  screenshot source within ~6 s (heartbeat staleness) without dropping client connections.
- Frames are encoded in the native ReplayKit orientation (not rotated upright like the
  screenshot path). The current `orientation` (CGImagePropertyOrientation 1-8) is exposed via
  the status endpoint and heartbeat.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `BROADCAST_CONTROL_PORT` | `9300` | Loopback port WDA listens on for the extension. The extension always connects to the compile-time default, so overriding this requires rebuilding the extension with a matching `FBBroadcastDefaultControlPort`. |
| `BROADCAST_EXT_BUNDLE_ID` | `<runner bundle id>.broadcast` | Bundle id preselected in the broadcast picker. Only needed if a re-signing pipeline renames the appex. |

## Build integration

- The `WebDriverAgentBroadcast` target is a dependency of `WebDriverAgentRunner`, so any
  scheme-based build (`xcodebuild build-for-testing -scheme WebDriverAgentRunner`, Fastlane,
  the npm bundle scripts) builds the appex into `BUILT_PRODUCTS_DIR`.
- A scheme **build post-action** (`Scripts/embed-broadcast-extension.sh`) copies the appex
  into `Runner.app/PlugIns/`, rewrites its `CFBundleIdentifier` to
  `<Runner.app CFBundleIdentifier>.broadcast` (the host id gets the `.xctrunner` suffix and may
  be overridden by downstream tooling, so it is derived at embed time) and re-signs
  inner-first. Post-actions run for scheme-based command-line builds too — the same mechanism
  that embeds the runner icon today.
- Builds that bypass the scheme (`xcodebuild -target ...`) must run the embed step manually:

  ```bash
  BUILT_PRODUCTS_DIR=<products dir> PRODUCT_NAME=WebDriverAgentRunner \
    Scripts/embed-broadcast-extension.sh
  ```

## Re-signing (device farms / prebuilt WDA)

Pipelines that re-sign `WebDriverAgentRunner-Runner.app` must keep the nested appex valid:

1. Sign `PlugIns/WebDriverAgentBroadcast.appex` first with the **same team/identity** as the
   app (or use `codesign --deep` on the app, which handles nesting). Signing the outer app does
   not invalidate an already-valid nested signature.
2. The appex `CFBundleIdentifier` must remain `<host CFBundleIdentifier>.broadcast` — installd
   rejects extensions whose bundle id is not prefixed by the host app's, or whose team differs.
   If the pipeline changes the runner's bundle id, patch the appex id accordingly (the embed
   script shows how) and set `BROADCAST_EXT_BUNDLE_ID` if the suffix differs.
3. Provisioning: the embedded profile must cover the appex bundle id; a wildcard development
   profile (`TEAM.*`) is the low-friction option. The extension needs no special entitlements
   (no app groups — IPC is loopback TCP).

## Architecture

```
WebDriverAgentRunner-Runner.app
├── PlugIns/WebDriverAgentRunner.xctest        WDA
│     FBBroadcastManager ─ FBBroadcastControlServer (127.0.0.1:9300)
│     FBVideoStreamManager → FBVideoStreamSession (TCP fan-out :9200+,
│       screenshot-encode or broadcast-passthrough per session)
└── PlugIns/WebDriverAgentBroadcast.appex      extension
      FBBroadcastSampleHandler (RPBroadcastSampleHandler)
        → FBExtSessionPipeline × N (VTPixelTransfer letterbox scale +
          FBVideoEncoder per session, 420v end to end)
        → FBExtBroadcastClient ──TCP──► WDA control port
```

The wire protocol (16-byte framed messages, JSON control payloads, binary video frames) is
defined in `WebDriverAgentLib/Utilities/FBBroadcastProtocol.h`, which is compiled into both
the framework and the extension.

Audio capture (Opus) is a planned follow-up; audio sample buffers are currently ignored.
