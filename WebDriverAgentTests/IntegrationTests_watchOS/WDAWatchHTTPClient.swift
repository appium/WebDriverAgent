/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

/// Minimal synchronous JSON/HTTP client for driving the real WebDriverAgentRunner_watchOS
/// server, the same way a real client (Appium, curl) would. Requires the server to already be
/// running, e.g. via `xcodebuild test -scheme WebDriverAgentRunner_watchOS`.
struct WDAWatchHTTPClient {
  struct Response {
    let statusCode: Int
    let json: [String: Any]?

    var value: Any? { json?["value"] }
    var valueDict: [String: Any]? { value as? [String: Any] }
    var valueString: String? { value as? String }
  }

  enum ClientError: Error, CustomStringConvertible {
    case requestFailed(String)

    var description: String {
      switch self {
      case .requestFailed(let message): return message
      }
    }
  }

  let baseURL: URL

  init() {
    let host = ProcessInfo.processInfo.environment["WDA_TEST_HOST"] ?? "127.0.0.1"
    let port = ProcessInfo.processInfo.environment["WDA_TEST_PORT"] ?? "8100"
    self.baseURL = URL(string: "http://\(host):\(port)")!
  }

  /// Splits path/query before resolving against baseURL - appendingPathComponent would
  /// percent-encode a literal "?" instead of treating it as a query delimiter.
  private func url(for path: String) -> URL {
    let parts = path.split(separator: "?", maxSplits: 1)
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
    components.path = components.path + parts[0]
    if parts.count > 1 {
      components.percentEncodedQuery = String(parts[1])
    }
    return components.url!
  }

  @discardableResult
  func send(_ method: String, _ path: String, body: [String: Any]? = nil, timeout: TimeInterval = 20) throws -> Response {
    var request = URLRequest(url: url(for: path))
    request.httpMethod = method
    request.timeoutInterval = timeout
    if let body = body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var resultData: Data?
    var resultResponse: URLResponse?
    var resultError: Error?

    URLSession.shared.dataTask(with: request) { data, response, error in
      resultData = data
      resultResponse = response
      resultError = error
      semaphore.signal()
    }.resume()

    if semaphore.wait(timeout: .now() + timeout + 5) == .timedOut {
      throw ClientError.requestFailed("Request to \(method) \(path) timed out")
    }
    if let resultError = resultError {
      throw ClientError.requestFailed("Request to \(method) \(path) failed: \(resultError)")
    }
    guard let httpResponse = resultResponse as? HTTPURLResponse else {
      throw ClientError.requestFailed("Request to \(method) \(path) returned no HTTP response")
    }
    var json: [String: Any]?
    if let resultData = resultData, !resultData.isEmpty {
      json = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any]
    }
    return Response(statusCode: httpResponse.statusCode, json: json)
  }

  func get(_ path: String) throws -> Response { try send("GET", path) }
  func post(_ path: String, body: [String: Any] = [:]) throws -> Response { try send("POST", path, body: body) }
  func delete(_ path: String) throws -> Response { try send("DELETE", path) }
}
