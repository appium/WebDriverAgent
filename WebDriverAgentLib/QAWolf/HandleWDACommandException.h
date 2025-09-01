//
//  HandleWDACommandException.h
//  ios-agent
//
//  Created by Elton Carreiro on 27/08/25.
//

#import <Foundation/Foundation.h>
#import <WebDriverAgentLib/FBResponsePayload.h>
#import <WebDriverAgentLib/FBExceptions.h>
#import <WebDriverAgentLib/FBCommandStatus.h>
#import <WebDriverAgentLib/FBResponseJSONPayload.h>

// Declare the function so it can be imported into Swift
FBResponseJSONPayload *FBCommandStatusForException(NSException *exception);
