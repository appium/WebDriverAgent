//
//  HandleWDACommandException.m
//  ios-agent
//
//  Created by Elton Carreiro on 27/08/25.
//

#import <WebDriverAgentLib/FBResponsePayload.h>
#import <WebDriverAgentLib/FBExceptions.h>
#import <WebDriverAgentLib/FBCommandStatus.h>
#import <WebDriverAgentLib/FBResponseJSONPayload.h>


FBResponseJSONPayload *FBCommandStatusForException(NSException *exception) {
  FBCommandStatus *commandStatus;
  NSString *traceback = [NSString stringWithFormat:@"%@", exception.callStackSymbols];

  if ([exception.name isEqualToString:FBSessionDoesNotExistException]) {
    commandStatus = [FBCommandStatus noSuchDriverErrorWithMessage:exception.reason
                                                        traceback:traceback];
  } else if ([exception.name isEqualToString:FBInvalidArgumentException]
             || [exception.name isEqualToString:FBElementAttributeUnknownException]
             || [exception.name isEqualToString:FBApplicationMissingException]) {
    commandStatus = [FBCommandStatus invalidArgumentErrorWithMessage:exception.reason
                                                           traceback:traceback];
  } else if ([exception.name isEqualToString:FBApplicationCrashedException]
             || [exception.name isEqualToString:FBApplicationDeadlockDetectedException]) {
    commandStatus = [FBCommandStatus invalidElementStateErrorWithMessage:exception.reason
                                                               traceback:traceback];
  } else if ([exception.name isEqualToString:FBInvalidXPathException]
             || [exception.name isEqualToString:FBClassChainQueryParseException]) {
    commandStatus = [FBCommandStatus invalidSelectorErrorWithMessage:exception.reason
                                                           traceback:traceback];
  } else if ([exception.name isEqualToString:FBElementNotVisibleException]) {
    commandStatus = [FBCommandStatus elementNotVisibleErrorWithMessage:exception.reason
                                                             traceback:traceback];
  } else if ([exception.name isEqualToString:FBStaleElementException]) {
    commandStatus = [FBCommandStatus staleElementReferenceErrorWithMessage:exception.reason
                                                                 traceback:traceback];
  } else if ([exception.name isEqualToString:FBTimeoutException]) {
    commandStatus = [FBCommandStatus timeoutErrorWithMessage:exception.reason
                                                   traceback:traceback];
  } else if ([exception.name isEqualToString:FBSessionCreationException]) {
    commandStatus = [FBCommandStatus sessionNotCreatedError:exception.reason
                                                  traceback:traceback];
  } else {
    commandStatus = [FBCommandStatus unknownErrorWithMessage:exception.reason
                                                   traceback:traceback];
  }

  return FBResponseWithStatus(commandStatus);
}
