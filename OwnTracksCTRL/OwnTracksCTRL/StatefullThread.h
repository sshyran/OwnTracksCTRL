//
//  OPMQTTPlusThread.h
//  OwnTracksGW
//
//  Created by Christoph Krey on 18.09.14.
//  Copyright © 2014-2016 christophkrey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MQTTClient/MQTTClient.h>

@interface StatefullThread : NSThread <MQTTSessionDelegate>
@property (nonatomic) BOOL terminate;
@property (strong, nonatomic) NSString *user;
@property (strong, nonatomic) NSString *passwd;
@property (strong, nonatomic) NSString *clientid;
@property (strong, nonatomic) NSString *host;
@property (strong, nonatomic) NSString *base;
@property (nonatomic) BOOL tls;
@property (nonatomic) int port;

@end
