//
//  ltalkVoipLib.h
//  ltalkVoipLib
//
//  Created by livecom on 14/12/29.
//  Copyright (c) 2014年 livecom. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DialProcessHandle
- (void)peerRing;
- (void)onCalling;
- (void)finish;
- (void)callfailed:(NSString*)reason;
- (void)hangup:(NSString*)status;
@end

@interface WebRTCLib : NSObject

+ (void)initRTCSSL;
+ (void)deInitRTCSSL;
- (instancetype)initWithHandler:(id<DialProcessHandle>)handler;
- (void)disconnect;
- (BOOL)startCallFrom:(NSString*)uuid
        userclass:(NSString*)userclass
                 dial:(NSString*)teleCode;
@end


@protocol CallbackProcessHandle

- (void)callstatus:(NSString*)msg;

@end

@interface Calllback: NSObject

- (instancetype)initWithHandler:(id<CallbackProcessHandle>)handler;
- (void)startCallbackFrom:(NSString*)local
                     dial:(NSString*)remote;

@end

