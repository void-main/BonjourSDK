//
//  BSBonjourClient.m
//  BonjourSDK
//
//  Created by Sun Peng on 14-10-16.
//  Copyright (c) 2014年 Peng Sun. All rights reserved.
//

#import "BSBonjourClient.h"

@interface NSNetService (ServiceComparison)

- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSNetService *)aService;
- (BOOL)isEqual:(id)object;

@end

@implementation NSNetService (ServiceComparison)

- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSNetService *)aService
{
    return [[self name] localizedCaseInsensitiveCompare:[aService name]];
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[NSNetService class]]) {
        return [self.name isEqual:[object name]];
    }

    return NO;
}

@end

@implementation BSBonjourClient

#pragma mark -
#pragma mark Initialization
- (id)initWithServiceType:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol delegate:(id<BSBonjourClientDelegate>)delegate {
    if (self = [super init]) {
        self.serviceType = serviceType;
        self.transportProtocol = transportProtocol;
        self.delegate = delegate;

        self.foundServices = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)dealloc {
    self.foundServices = nil;
}

#pragma mark -
#pragma mark Search
- (void)startSearching {
    if (_browser) {
        [self stopSearching];
    }

    _browser = [[NSNetServiceBrowser alloc] init];
    [_browser setDelegate:self];
    [_browser scheduleInRunLoop:[NSRunLoop currentRunLoop]
                        forMode:NSDefaultRunLoopMode];

    [_browser searchForServicesOfType:[self combinedType]
                             inDomain:@""];
}

- (void)stopSearching {
    if (_browser) {
        [_browser stop];
        [_browser removeFromRunLoop:[NSRunLoop currentRunLoop]
                            forMode:NSDefaultRunLoopMode];
        _browser = nil;
    }

    [_foundServices removeAllObjects];
}

#pragma mark -
#pragma mark Connection & Data Transmission
- (void)connectToServiceAtIndex:(NSInteger)index {
    NSNetService *service = [_foundServices objectAtIndex:index];
    [self connectToService:service];
}

- (void)connectToService:(NSNetService *)service {
    if (_connection) {
        [self disconnectFromService];
    }

    _connection = [[BSBonjourConnection alloc] initWithNetService:service];
    _connection.delegate = self;
    [_connection connect];
}

- (void)sendData:(NSData *)data {
    [_connection sendData:data];
}

- (void)disconnectFromService {
    if (_connection) {
        [_connection close];
        _connection = nil;
    }
}

#pragma mark -
#pragma mark BSBonjourConnectionDelegate
- (void)connectionEstablished:(BSBonjourConnection *)connection {
    if (self.delegate) {
        [self.delegate connectionEstablished:connection];
    }
}

- (void) connectionAttemptFailed:(BSBonjourConnection *)connection {
    if (self.delegate) {
        [self.delegate connectionAttemptFailed:connection];
    }
}

- (void) connectionTerminated:(BSBonjourConnection *)connection {
    if (self.delegate) {
        [self.delegate connectionTerminated:connection];
    }
}

- (void)receivedData:(NSData *)data viaConnection:(BSBonjourConnection *)connection {
    if (self.delegate) {
        [self.delegate receivedData:data];
    }
}



#pragma mark -
#pragma mark NSNetServiceBrowserDelegate
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    if (self.delegate) {
        [self.delegate searchStarted];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {

    if ([self.foundServices indexOfObject:aNetService] == NSNotFound) {
        [self.foundServices addObject:aNetService];
    }

    if (!moreComing && self.delegate) {
        [self sortServices];
        [self.delegate updateServiceList];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    if ([self.foundServices indexOfObject:aNetService] != NSNotFound) {
        [self.foundServices removeObject:aNetService];
    }

    if (!moreComing && self.delegate) {
        [self sortServices];
        [self.delegate updateServiceList];
    }
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    if (self.delegate) {
        [self.delegate searchStopped];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict {
    if (self.delegate) {
        [self.delegate searchFailed:[NSError errorWithDomain:kBSBonjourClientDomain
                                                                      code:kBSBonjourClientErrorBrowseFailed
                                                                  userInfo:errorDict]];
    }
}

#pragma mark -
#pragma mark Readonly Properties
- (NSString *)combinedType {
    return [NSString stringWithFormat:@"_%@._%@", self.serviceType, self.transportProtocol];
}

#pragma mark -
#pragma mark Helper Methods
- (void)sortServices {
    [_foundServices sortUsingSelector:@selector(localizedCaseInsensitiveCompareByName:)];
}

@end
