# Reverse TCP Tunnel for NAT-Restricted Environments

## Overview

WebDriverAgent (WDA) normally listens on a TCP port (default 8100) for incoming
HTTP connections. This works when the test client can reach the iOS device
directly, but fails in NAT-restricted environments where inbound connections to
the device are blocked — for example:

- iOS devices on cellular networks (symmetric NAT)
- Devices behind corporate firewalls with no port forwarding
- Multi-layer VPN tunnels
- Remote device farms without direct network access

The reverse tunnel feature solves this by having WDA initiate an **outbound** TCP
connection to an external relay server. The relay accepts normal HTTP requests
from Appium clients and forwards them to WDA through the tunnel.

## Architecture

```
Appium Client ──HTTP──▶ Relay Server ◀──TCP (reverse tunnel)── WDA on iOS
(any network)          (public IP)                            (behind NAT)
```

1. A relay server runs on a publicly accessible host
2. WDA starts and connects **outbound** to the relay
3. The Appium client sends HTTP requests to the relay
4. The relay forwards requests to WDA through the tunnel and returns responses

## Configuration

Set these environment variables **before** launching WDA:

| Variable | Required | Description |
|---|---|---|
| `WDA_RELAY_HOST` | Yes | Hostname or IP of the relay server |
| `WDA_RELAY_PORT` | No | Relay port (default: 8201) |

When `WDA_RELAY_HOST` is not set, the reverse tunnel is completely inactive and
WDA behaves exactly as before (zero impact on existing usage).

### Example: Xcode test launch

```bash
WDA_RELAY_HOST=relay.example.com WDA_RELAY_PORT=8201 \
  xcodebuild test-without-building \
  -project WebDriverAgent.xcodeproj \
  -scheme WebDriverAgentRunner \
  -destination 'id=DEVICE_UDID'
```

### Example: Appium client configuration

Point `appium:webDriverAgentUrl` at the relay server:

```json
{
  "appium:webDriverAgentUrl": "http://relay.example.com:8100"
}
```

## Running the Relay Server

A reference relay server implementation is provided at
[`docs/wda-relay-server.mjs`](wda-relay-server.mjs).

```bash
# Default ports: relay on 8201, HTTP proxy on 8100
node docs/wda-relay-server.mjs

# Custom ports
node docs/wda-relay-server.mjs 9201 9100
```

The relay listens on two ports:
- **Relay port** (default 8201): Accepts the reverse TCP connection from WDA
- **Proxy port** (default 8100): Accepts normal HTTP requests from Appium clients

## Protocol

The tunnel uses an 8-byte header framing protocol over a single persistent TCP
connection:

```
┌──────────────────┬──────────────────┬─────────────┐
│ Payload Length   │ Request ID       │ Payload     │
│ (4 bytes, BE)    │ (4 bytes, BE)    │ (variable)  │
└──────────────────┴──────────────────┴─────────────┘
```

- **Payload Length**: Big-endian uint32, size of the payload in bytes
- **Request ID**: Big-endian uint32, correlates requests with responses
- **Payload**: Raw HTTP request or response bytes

Request IDs allow reliable request-response correlation even if responses arrive
out of order.

## Resilience

- **Automatic reconnection** with exponential backoff (5s → 10s → 20s → ... → 60s cap)
- Backoff resets to 5s after a successful connection
- **SIGTERM/SIGHUP handling**: WDA ignores these signals to survive IDE
  disconnection, enabling wireless-only operation
- **Network monitoring**: WDA monitors network path changes and automatically
  restarts the HTTP server on interface transitions (e.g., WiFi ↔ cellular)
