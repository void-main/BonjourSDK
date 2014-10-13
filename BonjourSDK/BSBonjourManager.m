//
//  BSBonjourManager.m
//  BonjourSDK
//
//  Created by Sun Peng on 14-10-11.
//  Copyright (c) 2014年 Peng Sun. All rights reserved.
//

#import "BSBonjourManager.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet6/in6.h>

@interface BSBonjourManager (HelperMethods)

- (NSString *)typeStringFromTypeName:(NSString *)name transportProtocol:(NSString *)transportProtocol;

@end

@interface BSBonjourManager (SocketAndStream)

@property (nonatomic, weak) id<NSStreamDelegate> streamDelegate;

- (void)createSocketsAndStreams:(int *)port;

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
- (void)publish:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol delegate:(id<BSBonjourPublishDelegate>)delegate streamDelegate:(id<NSStreamDelegate>)streamDelegate error:(NSError **)error {

    int port = 0;
    [self createSocketsAndStreams:&port];

    if (port < 0) {
        *error = [NSError errorWithDomain:kBSBonjourPublishDomain
                            code:kBSBonjourPublishSocketCreateFailed
                        userInfo:nil];
        return;
    }

    self.streamDelegate = streamDelegate;

    NSString *typeString = [self typeStringFromTypeName:serviceType transportProtocol:transportProtocol];
    NSNetService *service = [[NSNetService alloc] initWithDomain:@""
                                                            type:typeString
                                                            name:@""
                                                            port:port];

    if (service) {
        [service setDelegate:self];
        [service publish];

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

- (void)createSocketsAndStreams:(int *)port
{
    BOOL                success;
    int                 err;
    int                 fd;
    int                 fd6;
    struct sockaddr_in  addr;
    struct sockaddr_in6 addr6;

    port = 0;

    // Create a IPv4 Socket
    fd = socket(AF_INET, SOCK_STREAM, 0);
    success = (fd != -1);

    if (success) {
        memset(&addr, 0, sizeof(addr));
        addr.sin_len    = sizeof(addr);
        addr.sin_family = AF_INET;
        addr.sin_port   = 0;
        addr.sin_addr.s_addr = INADDR_ANY;
        err = bind(fd, (const struct sockaddr *) &addr, sizeof(addr));
        success = (err == 0);
    }
    if (success) {
        err = listen(fd, 5);
        success = (err == 0);
    }
    if (success) {
        socklen_t   addrLen;

        addrLen = sizeof(addr);
        err = getsockname(fd, (struct sockaddr *) &addr, &addrLen);
        success = (err == 0);
    }

    // Then create a IPv6 Socket
    fd6 = socket(AF_INET6, SOCK_STREAM, 0);
    success = (fd6 != -1);

    if (success) {
        int one = 1;
        err = setsockopt(fd6, IPPROTO_IPV6, IPV6_V6ONLY, &one, sizeof(one));
        success = (err == 0);
    }
    if (success) {
        memset(&addr6, 0, sizeof(addr6));
        addr6.sin6_len    = sizeof(addr6);
        addr6.sin6_family = AF_INET6;
        addr6.sin6_port   = addr.sin_port;
        err = bind(fd6, (const struct sockaddr *) &addr6, sizeof(addr6));
        success = (err == 0);
    }
    if (success) {
        err = listen(fd6, 5);
        success = (err == 0);
    }
    if (success) {
        socklen_t   addrLen;

        addrLen = sizeof(addr6);
        err = getsockname(fd6, (struct sockaddr *) &addr6, &addrLen);
        success = (err == 0);

        if (success) {
            assert(addrLen == sizeof(addr6));
            assert(ntohs(addr6.sin6_port) == ntohs(addr.sin_port));
            *port = ntohs(addr6.sin6_port);
        }
    }

    // Hook up IPv4 CFSocket
    if (success) {
        CFSocketContext context = { 0, (__bridge void *) self, NULL, NULL, NULL };

        assert(_listeningIPv4Socket == NULL);
        _listeningIPv4Socket = CFSocketCreateWithNative(
                                                          NULL,
                                                          fd,
                                                          kCFSocketAcceptCallBack,
                                                          AcceptCallback,
                                                          &context
                                                          );
        success = (_listeningIPv4Socket != NULL);

        if (success) {
            CFRunLoopSourceRef  rls;

            fd = -1;        // listeningSocket is now responsible for closing fd
            
            rls = CFSocketCreateRunLoopSource(NULL, _listeningIPv4Socket, 0);
            assert(rls != NULL);
            
            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
            
            CFRelease(rls);
        }
    }

    // Then, hook up IPv6 CFSocket
    if (success) {
        CFSocketContext context = { 0, (__bridge void *) self, NULL, NULL, NULL };

        assert(_listeningIPv6Socket == NULL);
        _listeningIPv6Socket = CFSocketCreateWithNative(
                                                        NULL,
                                                        fd6,
                                                        kCFSocketAcceptCallBack,
                                                        AcceptCallback,
                                                        &context
                                                        );
        success = (_listeningIPv6Socket != NULL);

        if (success) {
            CFRunLoopSourceRef  rls;

            fd = -1;        // listeningSocket is now responsible for closing fd

            rls = CFSocketCreateRunLoopSource(NULL, _listeningIPv6Socket, 0);
            assert(rls != NULL);

            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);

            CFRelease(rls);
        }
    }

    if (!success){
        *port = -1;
    }
}

void AcceptCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
    int fd = * (const int *)data; // IPv4 or IPv6
    CFReadStreamRef   readStream;
    CFWriteStreamRef  writeStream;
    NSInputStream *   inputStream;
    NSOutputStream *  outputStream;

    CFStreamCreatePairWithSocket(NULL, fd, &readStream, &writeStream);
    inputStream = CFBridgingRelease(readStream);
    outputStream = CFBridgingRelease(writeStream);

    [inputStream setProperty:(id)kCFBooleanTrue forKey:(NSString *)kCFStreamPropertyShouldCloseNativeSocket];

    BSBonjourManager *manager = (__bridge BSBonjourManager *)info;
    [inputStream setDelegate:manager.streamDelegate];
    [outputStream setDelegate:manager.streamDelegate];
}


@end
