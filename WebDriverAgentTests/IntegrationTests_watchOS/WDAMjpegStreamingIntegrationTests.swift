/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Network
import XCTest

/// Exercises FBMjpegServer+FBTCPSocket the same way FBWebServer wires them together in
/// -initScreenshotsBroadcaster, but standalone (no full FBWebServer/HTTP command server needed).
/// A client NWConnection reads the raw wire bytes back to confirm the multipart/x-mixed-replace
/// stream and its JPEG frames actually arrive, since watchOS has no BSD sockets/GCDAsyncSocket -
/// the production implementation is Network.framework-backed and worth covering for real.
final class WDAMjpegStreamingIntegrationTests: WDAWatchInProcessTestCase {
  override class var relaunchForEachTest: Bool { false }

  private static let jpegMagicBytes: [UInt8] = [0xFF, 0xD8, 0xFF]

  func testMjpegStreamingProducesJpegFrames() throws {
    // Port 0 asks the system to assign an ephemeral port; -[FBTCPSocket port] then reflects the
    // actual bound port once -start returns, per nw_listener_get_port's documented behavior.
    let socket = FBTCPSocket(port: 0)
    let server = FBMjpegServer()
    server.socket = socket
    socket.delegate = server
    defer {
      server.stopStreaming()
      socket.stop()
    }
    try socket.start()
    let boundPort = socket.port
    XCTAssertNotEqual(boundPort, 0, "FBTCPSocket did not report its bound ephemeral port")

    let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: boundPort)!, using: .tcp)
    defer { connection.cancel() }

    let connected = expectation(description: "client connected to the mjpeg broadcaster")
    connection.stateUpdateHandler = { state in
      if case .ready = state {
        connected.fulfill()
      }
    }
    connection.start(queue: .main)
    wait(for: [connected], timeout: 15)

    // FBMjpegServer only starts broadcasting once it has seen any data from the client - mimic the
    // request line a real HTTP client would send.
    let sent = expectation(description: "sent the request line")
    connection.send(content: Data("GET / HTTP/1.0\r\n\r\n".utf8), completion: .contentProcessed { _ in
      sent.fulfill()
    })
    wait(for: [sent], timeout: 15)

    var received = Data()
    let jpegMagicData = Data(Self.jpegMagicBytes)
    let sawJpegFrame = expectation(description: "received at least one jpeg frame")
    func receiveMore() {
      connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
        if let data = data {
          received.append(data)
          if received.range(of: jpegMagicData) != nil {
            sawJpegFrame.fulfill()
            return
          }
        }
        if error == nil {
          receiveMore()
        }
      }
    }
    receiveMore()
    wait(for: [sawJpegFrame], timeout: 15)

    XCTAssertNotNil(received.range(of: Data("multipart/x-mixed-replace".utf8)), "Response is not a multipart stream")
    XCTAssertNotNil(received.range(of: Data("Content-type: image/jpeg".utf8)), "No JPEG part header found")
    XCTAssertNotNil(received.range(of: jpegMagicData), "No JPEG frame data found")
  }
}
