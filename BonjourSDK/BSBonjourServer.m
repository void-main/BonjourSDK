//
//  BSBonjourServer.m
//  BonjourSDK
//
//  Created by Sun Peng on 14-10-16.
//  Copyright (c) 2014年 Peng Sun. All rights reserved.
//

#import "BSBonjourServer.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet6/in6.h>

@interface BSBonjourServer (Sockets)

- (BOOL)createServerSockets;
- (void)closeSockets;

@end

@implementation BSBonjourServer

- (id)initWithServiceType:(NSString *)serviceType transportProtocol:(NSString *)transportProtocol delegate:(id<BSBonjourServerDelegate>)delegate {
    if (self = [super init]) {
        self.serviceType = serviceType;
        self.transportProtocol = transportProtocol;
        self.delegate = delegate;

        _connections = [[NSMutableSet alloc] init];
    }

    return self;
}

- (void)addConnection:(BSBonjourConnection *)connection {
    [_connections addObject:connection];
}

- (void)publish {
    if (_publishedService) { // Already listening
        [self unpublish];
    }

    if (![self createServerSockets]) {
        if (self.delegate) {
            [self.delegate publishFailed:[NSError errorWithDomain:kBSBonjourServerDomain
                                                             code:kBSBonjourServerSocketCreateFailed
                                                         userInfo:nil]];
        }
        return;
    }

    _publishedService = [[NSNetService alloc] initWithDomain:@""
                                                        type:[self combinedType]
                                                        name:@""
                                                        port:_port];

    if (_publishedService) {
        [_publishedService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

        [_publishedService setDelegate:self];
        [_publishedService publish];
    } else {
        [self closeSockets];
        if (self.delegate) {
            [self.delegate registerFailed:[NSError errorWithDomain:kBSBonjourServerDomain
                                                              code:kBSBonjourServerErrorRegisterFailed
                                                          userInfo:nil]];
        }
    }
}

- (void)unpublish {
    [self closeSockets];
    [_publishedService stop];
}

- (void)broadcastData:(NSData *)data {
    for (BSBonjourConnection *connection in _connections) {
        [connection sendData:data];
    }
}

- (void)sendData:(NSData *)data viaConnection:(BSBonjourConnection *)connection {
    [connection sendData:data];
}

#pragma mark -
#pragma mark BSBonjourConnectionDelegate
- (void) connectionEstablished:(BSBonjourConnection *)connection {
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
#pragma mark NSNetServiceDelegate
- (void)netServiceDidPublish:(NSNetService *)sender {
    if (self.delegate) {
        [self.delegate published:sender.name];
    }
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
    [self unpublish];
    if (self.delegate) {
        [self.delegate publishFailed:[NSError errorWithDomain:kBSBonjourServerDomain
                                                         code:kBSBonjourServerErrorPublishFailed
                                                     userInfo:errorDict]];
    }
}

- (void)netServiceDidStop:(NSNetService *)sender {
    if (self.delegate) {
        [self.delegate serviceStopped:sender.name];

        [_publishedService removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        _publishedService = nil;
    }
}


#pragma mark -
#pragma mark Readonly Properties
- (NSString *)combinedType {
    return [NSString stringWithFormat:@"_%@._%@", self.serviceType, self.transportProtocol];
}

- (NSNetService *)publishedService {
    return _publishedService;
}

#pragma mark -
#pragma mark Helper Methods
- (BOOL)createServerSockets
{
    BOOL                success;
    int                 err;
    int                 fd;
    int                 fd6;
    struct sockaddr_in  addr;
    struct sockaddr_in6 addr6;

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
            _port = ntohs(addr6.sin6_port);
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
        _port = -1;
    }

    return success;
}

- (void)closeSockets {
    if (_listeningIPv4Socket != nil) {
        CFSocketInvalidate(_listeningIPv4Socket);
        CFRelease(_listeningIPv4Socket);
        _listeningIPv4Socket = nil;
    }

    if (_listeningIPv6Socket != nil) {
        CFSocketInvalidate(_listeningIPv6Socket);
        CFRelease(_listeningIPv6Socket);
        _listeningIPv6Socket = nil;
    }
}

void AcceptCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
    // We can only process "connection accepted" calls here
    if ( type != kCFSocketAcceptCallBack ) {
        return;
    }

    // for an AcceptCallBack, the data parameter is a pointer to a CFSocketNativeHandle
    CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
    BSBonjourServer *service = (__bridge BSBonjourServer *)info;
    BSBonjourConnection *connection = [[BSBonjourConnection alloc] initWithNativeSocketHandle:nativeSocketHandle];
    connection.delegate = service;

    // In case of errors, close native socket handle
    if ( connection == nil ) {
        close(nativeSocketHandle);
        return;
    }

    // finish connecting
    BOOL succeed = [connection connect];
    if ( !succeed ) {
        [connection close];
        return;
    }

    [service addConnection:connection];
}


@end
