//
//  WDACommandExecute.h
//  ios-agent
//
//  Created by Elton Carreiro on 28/08/25.
//

#import <Foundation/Foundation.h>
#import <WebDriverAgentLib/FBCommandStatus.h>
#import <WebDriverAgentLib/FBResponseJSONPayload.h>

typedef FBResponseJSONPayload * _Nonnull (^WDACommand)(void);

/// Runs a block safely, catching NSException and mapping it to FBCommandStatus
FBResponseJSONPayload * _Nonnull ExecuteWDACommand(WDACommand _Nonnull block);
