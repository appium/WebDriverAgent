/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBElementHelpers.h"

BOOL FBDoesElementSupportInnerText(XCUIElementType elementType) {
  return elementType == XCUIElementTypeTextView
    || elementType == XCUIElementTypeTextField
    || elementType == XCUIElementTypeSearchField
    || elementType == XCUIElementTypeSecureTextField;
}

BOOL FBDoesElementSupportMinMaxValue(XCUIElementType elementType) {
  return elementType == XCUIElementTypeSlider
      || elementType == XCUIElementTypeStepper;
}
