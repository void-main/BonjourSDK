//
//  BSBonjourManager.m
//  BonjourSDK
//
//  Created by Sun Peng on 14-10-11.
//  Copyright (c) 2014年 Peng Sun. All rights reserved.
//

#import "BSBonjourManager.h"

@interface BSBonjourManager (HelperMethods)

- (NSString *)typeStringFromTypeName:(NSString *)name transportProtocol:(NSString *)transportProtocol;

@end

@implementation BSBonjourManager

#pragma mark -
#pragma mark Singleton & Initialization

+ (id)sharedManager {
    static BSBonjourManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (id) init {
    if (self = [super init]) {
        self.publishedServices = [[NSMutableDictionary alloc] init];
        self.publishDelegates = [[NSMutableDictionary alloc] init];
    }

    return self;
}

#pragma mark -
#pragma mark Bonjour Publish
- (void)publish:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol port:(uint16_t)port delegate:(id<BSBonjourPublishDelegate>)delegate {
    NSString *typeString = [self typeStringFromTypeName:serviceType transportProtocol:transportProtocol];
    NSNetService *service = [[NSNetService alloc] initWithDomain:@""
                                                            type:typeString
                                                            name:@""
                                                            port:port
                             ];

    if (service) {
        [service setDelegate:self];

        if (port) {
            [service publish];
        } else {
            [service publishWithOptions:NSNetServiceListenForConnections];
        }

        [self.publishedServices setObject:service forKey:[typeString stringByAppendingString:@"."]];
        [self.publishDelegates setObject:delegate forKey:[typeString stringByAppendingString:@"."]];
    } else {
        if (delegate) {
            [delegate registerFailed:[NSError errorWithDomain:kBSBonjourPublishDomain
                                                         code:kBSBonjourPublishErrorRegisterFailed
                                                     userInfo:nil]];
        }
    }
}

- (void)reclaim:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol {
    NSString *typeString = [self typeStringFromTypeName:serviceType transportProtocol:transportProtocol];
    NSNetService *serviceToReclaim = [self.publishedServices objectForKey:[typeString stringByAppendingString:@"."]];
    [serviceToReclaim stop];
}

#pragma mark -
#pragma mkar Bonjour Searching
- (void)search:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol delegate:(id<BSBonjourBrowseDelegate>)delegate {
    if (self.serviceBrowser) { // Browsing Services
        return;
    }

    NSString *typeString = [self typeStringFromTypeName:serviceType transportProtocol:transportProtocol];
    self.serviceBrowser = [[NSNetServiceBrowser alloc] init];
    [self.serviceBrowser setDelegate:self];
    self.serviceBrowserDelegate = delegate;
    
    [self.serviceBrowser searchForServicesOfType:typeString inDomain:@""];
}

- (void)stopSearch:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol {
    if (self.serviceBrowser) {
        [self.serviceBrowser stop];
    }
}

#pragma mark -
#pragma mark Bonjour Resolve
- (void)connectToService:(NSNetService *)service delegate:(id<NSStreamDelegate>)delegate error:(NSError **)error {
    NSInputStream *inStream = nil;
    NSOutputStream *outStream = nil;

    [service getInputStream:&inStream outputStream:&outStream];
    if (inStream && outStream)
    {
        inStream.delegate = delegate;
        outStream.delegate = delegate;

        [inStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                            forMode:NSDefaultRunLoopMode];
        [outStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                             forMode:NSDefaultRunLoopMode];

        [inStream open];
        [outStream open];
    }
    else {
        *error = [NSError errorWithDomain:kBSBonjourConnectDomain
                                     code:kBSBonjourConnectErrorConnectFailed
                                 userInfo:nil];
    }
}

#pragma mark -
#pragma mark NSNetServiceDelegate
- (void)netServiceWillPublish:(NSNetService *)sender {
    // Nothing to do
}

- (void)netServiceDidPublish:(NSNetService *)sender {
    NSString *type = sender.type;
    id<BSBonjourPublishDelegate> delegate = [self.publishDelegates objectForKey:type];
    if (delegate) {
        [delegate published:sender.name];
    }
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
    NSString *type = sender.type;
    [self.publishedServices removeObjectForKey:type];
    id<BSBonjourPublishDelegate> delegate = [self.publishDelegates objectForKey:type];
    if (delegate) {
        [delegate publishFailed:[NSError errorWithDomain:kBSBonjourPublishDomain
                                                    code:kBSBonjourPublishErrorPublishFailed
                                                userInfo:errorDict]];
    }
}

- (void)netServiceDidStop:(NSNetService *)sender {
    NSString *type = sender.type;
    [self.publishedServices removeObjectForKey:type];
    id<BSBonjourPublishDelegate> delegate = [self.publishDelegates objectForKey:type];
    if (delegate) {
        [delegate serviceStopped:sender.name];
        [self.publishDelegates removeObjectForKey:type];
    }
}

#pragma mark -
#pragma mark NSNetServiceBrowserDelegate
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    if (self.serviceBrowserDelegate) {
        [self.serviceBrowserDelegate searchStarted];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    if (self.serviceBrowserDelegate) {
        [self.serviceBrowserDelegate didFindService:aNetService moreComing:moreComing];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    if (self.serviceBrowserDelegate) {
        [self.serviceBrowserDelegate didRemoveService:aNetService moreComing:moreComing];
    }
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    if (self.serviceBrowserDelegate) {
        [self.serviceBrowserDelegate searchStopped];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict {
    if (self.serviceBrowserDelegate) {
        [self.serviceBrowserDelegate searchFailed:[NSError errorWithDomain:kBSBonjourBrowseDomain
                                                                      code:kBSBonjourBrowseErrorBrowseFailed
                                                                  userInfo:errorDict]];
    }
}

#pragma mark -
#pragma mark Helper Methods
- (NSString *)typeStringFromTypeName:(NSString *)typeName transportProtocol:(NSString *)transportProtocol {
    return [NSString stringWithFormat:@"_%@._%@", typeName, transportProtocol];
}

@end
