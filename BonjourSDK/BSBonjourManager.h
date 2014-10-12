//
//  BSBonjourManager.h
//  BonjourSDK
//
//  Created by Sun Peng on 14-10-11.
//  Copyright (c) 2014年 Peng Sun. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kBSBonjourPublishDomain @"BSBonjourPublish"
#define kBSBonjourPublishErrorRegisterFailed -1
#define kBSBonjourPublishErrorPublishFailed  -2

#define kBSBonjourBrowseDomain @"BSBonjourBrowse"
#define kBSBonjourBrowseErrorBrowseFailed -1

#define kBSBonjourConnectDomain @"BSBonjourConnect"
#define kBSBonjourConnectErrorConnectFailed  -1

@protocol BSBonjourPublishDelegate <NSObject>

- (void)published:(NSString *)name;
- (void)serviceStopped:(NSString *)name;
- (void)registerFailed:(NSError *)error;
- (void)publishFailed:(NSError *)error;

@end

@protocol BSBonjourBrowseDelegate <NSObject>

- (void)didFindService:(NSNetService *)service moreComing:(BOOL)moreComing;
- (void)didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing;

- (void)searchStarted;
- (void)searchFailed:(NSError *)error;
- (void)searchStopped;

@end

@interface BSBonjourManager : NSObject <NSNetServiceDelegate, NSNetServiceBrowserDelegate>

@property (nonatomic, strong) NSMutableDictionary *publishedServices;
@property (nonatomic, strong) NSMutableDictionary *publishDelegates;

@property (nonatomic, strong) NSNetServiceBrowser        *serviceBrowser;
@property (nonatomic, strong) id<BSBonjourBrowseDelegate> serviceBrowserDelegate;

// Singleton Method
+ (id)sharedManager;

// Bonjour Publish
- (void)publish:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol port:(uint16_t)port delegate:(id<BSBonjourPublishDelegate>)delegate;
- (void)reclaim:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol;

// Bonjour Search
- (void)search:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol delegate:(id<BSBonjourBrowseDelegate>)delegate;
- (void)stopSearch:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol;

// Resolve
- (void)connectToService:(NSNetService *)service delegate:(id<NSStreamDelegate>)delegate error:(NSError **)error;

@end
