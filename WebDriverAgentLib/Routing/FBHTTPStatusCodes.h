/*
 * Copyright (C) 2013 Neo Visionaries Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


#ifndef FBHTTPStatusCodes_h
#define FBHTTPStatusCodes_h


//----------------------------------------------------------------------
// Typedef
//----------------------------------------------------------------------

/**
 * HTTP status codes.
 *
 * The list here is based on the description at Wikipedia.
 * The initial version of this list was written on April 20, 2013.
 *
 * @see <a href="http://en.wikipedia.org/wiki/List_of_HTTP_status_codes">List of HTTP status codes</a>
 */
typedef enum
{
  /*--------------------------------------------------
   * 1xx Informational
   *------------------------------------------------*/

  /**
   * 100 Continue.
   */
  kHTTPStatusCodeContinue = 100,

  /**
   * 101 Switching Protocols.
   */
  kHTTPStatusCodeSwitchingProtocols = 101,

#if !defined(HTTP_STATUS_CODES_EXCLUDE_WEBDAV) && !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_2518)
  /**
   * 103 Processing (WebDAV; RFC 2518).
   */
  kHTTPStatusCodeProcessing = 102,
#endif

  /*--------------------------------------------------
   * 2xx Success
   *------------------------------------------------*/

  /**
   * 200 OK.
   */
  kHTTPStatusCodeOK = 200,

  /**
   * 201 Created.
   */
  kHTTPStatusCodeCreated = 201,

  /**
   * 202 Accepted.
   */
  kHTTPStatusCodeAccepted = 202,

  /**
   * 203 Non-Authoritative Information (since HTTP/1.1).
   */
  kHTTPStatusCodeNonAuthoritativeInformation = 203,

  /**
   * 204 No Content.
   */
  kHTTPStatusCodeNoContent = 204,

  /**
   * 205 Reset Content.
   */
  kHTTPStatusCodeResetContent = 205,

  /**
   * 206 Partial Content.
   */
  kHTTPStatusCodePartialContent = 206,

#if !defined(HTTP_STATUS_CODES_EXCLUDE_WEBDAV) && !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_4918)
  /**
   * 207 Multi-Status (WebDAV; RFC 4918).
   */
  kHTTPStatusCodeMultiStatus = 207,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_WEBDAV) && !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_5842)
  /**
   * 208 Already Reported (WebDAV; RFC 5842).
   */
  kHTTPStatusCodeAlreadyReported = 208,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_3229)
  /**
   * 226 IM Used (RFC 3229)
   */
  kHTTPStatusCodeIMUsed = 226,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP) && !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_2326)
  /**
   * 250 Low on Storage Space (RTSP; RFC 2326).
   */
  kHTTPStatusCodeLowOnStorageSpace = 250,
#endif

  /*--------------------------------------------------
   * 3xx Redirection
   *------------------------------------------------*/

  /**
   * 300 Multiple Choices.
   */
  kHTTPStatusCodeMultipleChoices = 300,

  /**
   * 301 Moved Permanently.
   */
  kHTTPStatusCodeMovedPermanently = 301,

  /**
   * 302 Found.
   */
  kHTTPStatusCodeFound = 302,

  /**
   * 303 See Other (since HTTP/1.1).
   */
  kHTTPStatusCodeSeeOther = 303,

  /**
   * 304 Not Modified.
   */
  kHTTPStatusCodeNotModified = 304,

  /**
   * 305 Use Proxy (since HTTP/1.1).
   */
  kHTTPStatusCodeUseProxy = 305,

  /**
   * 306 Switch Proxy.
   */
  kHTTPStatusCodeSwitchProxy = 306,

  /**
   * 307 Temporary Redirect (since HTTP/1.1).
   */
  kHTTPStatusCodeTemporaryRedirect = 307,

  /**
   * 308 Permanent Redirect (approved as experimental RFC).
   */
  kHTTPStatusCodePermanentRedirect = 308,

  /*--------------------------------------------------
   * 4xx Client Error
   *------------------------------------------------*/

  /**
   * 400 Bad Request.
   */
  kHTTPStatusCodeBadRequest = 400,

  /**
   * 401 Unauthorized.
   */
  kHTTPStatusCodeUnauthorized = 401,

  /**
   * 402 Payment Required.
   */
  kHTTPStatusCodePaymentRequired = 402,

  /**
   * 403 Forbidden.
   */
  kHTTPStatusCodeForbidden = 403,

  /**
   * 404 Not Found.
   */
  kHTTPStatusCodeNotFound = 404,

  /**
   * 405 Method Not Allowed.
   */
  kHTTPStatusCodeMethodNotAllowed = 405,

  /**
   * 406 Not Acceptable.
   */
  kHTTPStatusCodeNotAcceptable = 406,

  /**
   * 407 Proxy Authentication Required.
   */
  kHTTPStatusCodeProxyAuthenticationRequired = 407,

  /**
   * 408 Request Timeout.
   */
  kHTTPStatusCodeRequestTimeout = 408,

  /**
   * 409 Conflict.
   */
  kHTTPStatusCodeConflict = 409,

  /**
   * 410 Gone.
   */
  kHTTPStatusCodeGone = 410,

  /**
   * 411 Length Required.
   */
  kHTTPStatusCodeLengthRequired = 411,

  /**
   * 412 Precondition Failed.
   */
  kHTTPStatusCodePreconditionFailed = 412,

  /**
   * 413 Request Entity Too Large.
   */
  kHTTPStatusCodeRequestEntityTooLarge = 413,

  /**
   * 414 Request-URI Too Long.
   */
  kHTTPStatusCodeRequestURITooLong = 414,

  /**
   * 415 Unsupported Media Type.
   */
  kHTTPStatusCodeUnsupportedMediaType = 415,

  /**
   * 416 Requested Range Not Satisfiable.
   */
  kHTTPStatusCodeRequestedRangeNotSatisfiable = 416,

  /**
   * 417 Expectation Failed.
   */
  kHTTPStatusCodeExpectationFailed = 417,

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_2324)
  /**
   * 418 I'm a teapot (RFC 2324).
   */
  kHTTPStatusCodeImATeapot = 418,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_TWITTER)
  /**
   * 420 Enhance Your Calm (Twitter).
   */
  kHTTPStatusCodeEnhanceYourCalm = 420,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_WEBDAV) && !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_4918)
  /**
   * 422 Unprocessable Entity (WebDAV; RFC 4918).
   */
  kHTTPStatusCodeUnprocessableEntity = 422,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_WEBDAV) && !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_4918)
  /**
   * 423 Locked (WebDAV; RFC 4918).
   */
  kHTTPStatusCodeLocked = 423,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_WEBDAV) && !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_4918)
  /**
   * 424 Failed Dependency (WebDAV; RFC 4918).
   */
  kHTTPStatusCodeFailedDependency = 424,
#endif

  /**
   * 425 Unordered Collection (Internet draft).
   */
  kHTTPStatusCodeUnorderedCollection = 425,

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_2817)
  /**
   * 426 Upgrade Required (RFC 2817).
   */
  kHTTPStatusCodeUpgradeRequired = 426,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_6585)
  /**
   * 428 Precondition Required (RFC 6585).
   */
  kHTTPStatusCodePreconditionRequired = 428,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_6585)
  /**
   * 429 Too Many Requests (RFC 6585).
   */
  kHTTPStatusCodeTooManyRequests = 429,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_6585)
  /**
   * 431 Request Header Fields Too Large (RFC 6585).
   */
  kHTTPStatusCodeRequestHeaderFieldsTooLarge = 431,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_NGINX)
  /**
   * 444 No Response (Nginx).
   */
  kHTTPStatusCodeNoResponse = 444,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_MICROSOFT)
  /**
   * 449 Retry With (Microsoft).
   */
  kHTTPStatusCodeRetryWith = 449,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_MICROSOFT)
  /**
   * 450 Blocked by Windows Parental Controls (Microsoft).
   */
  kHTTPStatusCodeBlockedByWindowsParentalControls = 450,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 451 Parameter Not Understood (RTSP).
   */
  kHTTPStatusCodeParameterNotUnderstood = 451,
#endif

  /**
   * 451 Unavailable For Legal Reasons (Internet draft).
   */
  kHTTPStatusCodeUnavailableForLegalReasons = 451,

#if !defined(HTTP_STATUS_CODES_EXCLUDE_MICROSOFT)
  /**
   * 451 Redirect (Microsoft).
   */
  kHTTPStatusCodeRedirect = 451,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 452 Conference Not Found (RTSP).
   */
  kHTTPStatusCodeConferenceNotFound = 452,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 453 Not Enough Bandwidth (RTSP).
   */
  kHTTPStatusCodeNotEnoughBandwidth = 453,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 454 Session Not Found (RTSP).
   */
  kHTTPStatusCodeSessionNotFound = 454,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 455 Method Not Valid in This State (RTSP).
   */
  kHTTPStatusCodeMethodNotValidInThisState = 455,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 456 Header Field Not Valid for Resource (RTSP).
   */
  kHTTPStatusCodeHeaderFieldNotValidForResource = 456,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 457 Invalid Range (RTSP).
   */
  kHTTPStatusCodeInvalidRange = 457,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 458 Parameter Is Read-Only (RTSP).
   */
  kHTTPStatusCodeParameterIsReadOnly = 458,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 459 Aggregate Operation Not Allowed (RTSP).
   */
  kHTTPStatusCodeAggregateOperationNotAllowed = 459,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 460 Only Aggregate Operation Allowed (RTSP).
   */
  kHTTPStatusCodeOnlyAggregateOperationAllowed = 460,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 461 Unsupported Transport (RTSP).
   */
  kHTTPStatusCodeUnsupportedTransport = 461,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 462 Destination Unreachable (RTSP).
   */
  kHTTPStatusCodeDestinationUnreachable = 462,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_NGINX)
  /**
   * 494 Request Header Too Large (Nginx).
   */
  kHTTPStatusCodeRequestHeaderTooLarge = 494,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_NGINX)
  /**
   * 495 Cert Error (Nginx).
   */
  kHTTPStatusCodeCertError = 495,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_NGINX)
  /**
   * 496 No Cert (Nginx).
   */
  kHTTPStatusCodeNoCert = 496,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_NGINX)
  /**
   * 497 HTTP to HTTPS (Nginx).
   */
  kHTTPStatusCodeHTTPToHTTPS = 497,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_NGINX)
  /**
   * 499 Client Closed Request (Nginx).
   */
  kHTTPStatusCodeClientClosedRequest = 499,
#endif

  /*--------------------------------------------------
   * 5xx Server Error
   *------------------------------------------------*/

  /**
   * 500 Internal Server Error.
   */
  kHTTPStatusCodeInternalServerError = 500,

  /**
   * 501 Not Implemented
   */
  kHTTPStatusCodeNotImplemented = 501,

  /**
   * 502 Bad Gateway.
   */
  kHTTPStatusCodeBadGateway = 502,

  /**
   * 503 Service Unavailable.
   */
  kHTTPStatusCodeServiceUnavailable = 503,

  /**
   * 504 Gateway Timeout.
   */
  kHTTPStatusCodeGatewayTimeout = 504,

  /**
   * 505 HTTP Version Not Supported.
   */
  kHTTPStatusCodeHTTPVersionNotSupported = 505,

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_2295)
  /**
   * 506 Variant Also Negotiates (RFC 2295).
   */
  kHTTPStatusCodeVariantAlsoNegotiates = 506,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_WEBDAV) && !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_4918)
  /**
   * 507 Insufficient Storage (WebDAV; RFC 4918).
   */
  kHTTPStatusCodeInsufficientStorage = 507,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_WEBDAV) && !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_5842)
  /**
   * 508 Loop Detected (WebDAV; RFC 5842).
   */
  kHTTPStatusCodeLoopDetected = 508,
#endif

  /**
   * 509 Bandwidth Limit Exceeded (Apache bw/limited extension).
   */
  kHTTPStatusCodeBandwidthLimitExceeded = 509,

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_2774)
  /**
   * 510 Not Extended (RFC 2774).
   */
  kHTTPStatusCodeNotExtended = 510,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RFC_6585)
  /**
   * 511 Network Authentication Required (RFC 6585).
   */
  kHTTPStatusCodeNetworkAuthenticationRequired = 511,
#endif

#if !defined(HTTP_STATUS_CODES_EXCLUDE_RTSP)
  /**
   * 551 Option not supported (RTSP).
   */
  kHTTPStatusCodeOptionNotSupported = 551,
#endif

  /**
   * 598 Network read timeout error (Unknown).
   */
  kHTTPStatusCodeNetworkReadTimeoutError = 598,

  /**
   * 599 Network connect timeout error (Unknown).
   */
  kHTTPStatusCodeNetworkConnectTimeoutError = 599
}
HTTPStatusCode;


#endif
