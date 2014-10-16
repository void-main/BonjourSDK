//
//  BSBonjourServer.h
//  BonjourSDK
//
//  Created by Sun Peng on 14-10-16.
//  Copyright (c) 2014年 Peng Sun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BSBonjourConnection.h"

#define kBSBonjourServerDomain @"BSBonjourPublish"
#define kBSBonjourServerErrorRegisterFailed -1
#define kBSBonjourServerErrorPublishFailed  -2
#define kBSBonjourServerSocketCreateFailed  -3

@protocol BSBonjourServerDelegate <NSObject>

- (void)published:(NSString *)name;
- (void)serviceStopped:(NSString *)name;
- (void)registerFailed:(NSError *)error;
- (void)publishFailed:(NSError *)error;

- (void)connectionEstablished:(BSBonjourConnection *)connection;
- (void)connectionAttemptFailed:(BSBonjourConnection *)connection;
- (void)connectionTerminated:(BSBonjourConnection *)connection;
- (void)receivedData:(NSData *)data;

@end

@interface BSBonjourServer : NSObject <NSNetServiceDelegate, BSBonjourConnectionDelegate> {
    int           _port;
    CFSocketRef   _listeningIPv4Socket;
    CFSocketRef   _listeningIPv6Socket;

    NSMutableSet *_connections;

    NSNetService *_publishedService;
}

#pragma mark -
#pragma mark Bonjour Service Type Naming
@property (nonatomic, strong) NSString *serviceType;
@property (nonatomic, strong) NSString *transportProtocol;
- (NSString *)combinedType;

#pragma mark -
#pragma mark Service and Delegate
- (NSNetService *)publishedService;
@property (nonatomic, strong) id<BSBonjourServerDelegate> delegate;

#pragma mark -
#pragma mark Initialization
- (id)initWithServiceType:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol delegate:(id<BSBonjourServerDelegate>)delegate;
- (void)addConnection:(BSBonjourConnection *)connection;

#pragma mark -
#pragma mark Service Publish & Unpublish
- (void)publish;
- (void)unpublish;

#pragma mark -
#pragma mark Data Transmission
- (void)broadcastData:(NSData *)data;
- (void)sendData:(NSData *)data viaConnection:(BSBonjourConnection *)connection;

@end
