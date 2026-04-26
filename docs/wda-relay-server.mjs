#!/usr/bin/env node
/**
 * WDA Reverse Tunnel Relay Server
 *
 * This server acts as a bridge between WDA (running on an iOS device behind NAT)
 * and HTTP clients. WDA connects outbound to this relay; HTTP clients connect
 * to localhost:8100 as usual.
 *
 * Usage:
 *   WDA_RELAY_HOST=<this-server-ip> WDA_RELAY_PORT=8201 xcodebuild test-without-building ...
 *   node wda-relay-server.mjs              # relay on 8201, proxy on 8100
 *   node wda-relay-server.mjs 9201 9100    # custom ports
 *
 * Protocol (between relay and WDA):
 *   [4-byte big-endian length][payload]
 *   Request payload:  raw HTTP request  (method + headers + body)
 *   Response payload: raw HTTP response (status + headers + body)
 */

import net from 'node:net';
import http from 'node:http';

const DEFAULT_RELAY_PORT = 8201;
const DEFAULT_PROXY_PORT = 8100;

const RELAY_PORT = parseInt(process.argv[2]) || DEFAULT_RELAY_PORT;
const PROXY_PORT = parseInt(process.argv[3]) || DEFAULT_PROXY_PORT;

let wdaSocket = null;
const pendingRequests = new Map();
let requestCounter = 0;

// --- Relay server: accepts reverse connection from WDA ---
const relayServer = net.createServer((socket) => {
  console.log(`[relay] WDA connected from ${socket.remoteAddress}`);
  wdaSocket = socket;

  let buffer = Buffer.alloc(0);

  socket.on('data', (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);

    while (buffer.length >= 4) {
      const len = buffer.readUInt32BE(0);
      if (buffer.length < 4 + len) break;

      const payload = buffer.subarray(4, 4 + len);
      buffer = buffer.subarray(4 + len);

      // Route response to the oldest pending HTTP request
      const oldest = pendingRequests.entries().next().value;
      if (oldest) {
        const [id, res] = oldest;
        pendingRequests.delete(id);

        const text = payload.toString();
        const headerEnd = text.indexOf('\r\n\r\n');
        if (headerEnd !== -1) {
          const statusMatch = text.match(/^HTTP\/\d\.\d (\d+)/);
          const statusCode = statusMatch ? parseInt(statusMatch[1]) : 200;
          const body = payload.subarray(headerEnd + 4);
          res.writeHead(statusCode, { 'Content-Type': 'application/json' });
          res.end(body);
        } else {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(payload);
        }
      }
    }
  });

  socket.on('close', () => {
    console.log('[relay] WDA disconnected');
    wdaSocket = null;
  });

  socket.on('error', (err) => {
    console.error('[relay] Socket error:', err.message);
    wdaSocket = null;
  });
});

// --- HTTP proxy: accepts normal WDA API requests ---
const proxyServer = http.createServer((req, res) => {
  if (!wdaSocket || wdaSocket.destroyed) {
    res.writeHead(503, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'WDA not connected to relay' }));
    return;
  }

  const body = [];
  req.on('data', (chunk) => body.push(chunk));
  req.on('end', () => {
    const bodyBuf = Buffer.concat(body);
    const httpReq = `${req.method} ${req.url} HTTP/1.1\r\nHost: localhost\r\n` +
      Object.entries(req.headers).map(([k, v]) => `${k}: ${v}`).join('\r\n') +
      '\r\n\r\n' + bodyBuf.toString();

    const reqBuf = Buffer.from(httpReq);
    const lenBuf = Buffer.alloc(4);
    lenBuf.writeUInt32BE(reqBuf.length);

    const id = requestCounter++;
    pendingRequests.set(id, res);

    try {
      wdaSocket.write(Buffer.concat([lenBuf, reqBuf]));
    } catch (err) {
      pendingRequests.delete(id);
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Failed to forward request' }));
    }
  });
});

relayServer.listen(RELAY_PORT, () => {
  console.log(`[relay] Waiting for WDA on port ${RELAY_PORT}`);
});

proxyServer.listen(PROXY_PORT, () => {
  console.log(`[proxy] HTTP proxy on port ${PROXY_PORT}`);
  console.log(`\nUsage: set WDA_RELAY_HOST and WDA_RELAY_PORT env vars when launching WDA`);
  console.log(`  WDA_RELAY_HOST=<this-ip> WDA_RELAY_PORT=${RELAY_PORT} xcodebuild test-without-building ...`);
  console.log(`  curl http://localhost:${PROXY_PORT}/status`);
});
