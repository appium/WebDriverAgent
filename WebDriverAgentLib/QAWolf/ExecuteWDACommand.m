//
//  ExecuteWDACommand.m
//  ios-agent
//
//  Created by Elton Carreiro on 28/08/25.
//

#import "ExecuteWDACommand.h"
#import "HandleWDACommandException.h"
#import <WebDriverAgentLib/FBResponseJSONPayload.h>

FBResponseJSONPayload * _Nonnull ExecuteWDACommand(WDACommand block) {
  @try {
    // Run the block (ignore result here, or change signature to return both)
    return block();
  }
  @catch (NSException *exception) {
    return FBCommandStatusForException(exception);
  }
}
