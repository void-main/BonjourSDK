//
//  BSBonjourConnection.h
//  BonjourSDK
//
//  Created by Sun Peng on 14-10-16.
//  Copyright (c) 2014年 Peng Sun. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BSBonjourConnection;

@protocol BSBonjourConnectionDelegate

- (void) connectionAttemptFailed:(BSBonjourConnection *)connection;
- (void) connectionTerminated:(BSBonjourConnection *)connection;
- (void) receivedData:(NSData *)data viaConnection:(BSBonjourConnection *)connection;

@end

@interface BSBonjourConnection : NSObject <NSNetServiceDelegate> {
    NSString *              _host;
    NSInteger               _port;
    
    CFSocketNativeHandle    _connectedSocketHandle;
    NSNetService *          _netService;

    CFReadStreamRef         _readStream;
    BOOL                    _readStreamOpen;
    NSMutableData *         _incomingDataBuffer;
    int	                    _dataSize;

    CFWriteStreamRef        _writeStream;
    BOOL                    _writeStreamOpen;
    NSMutableData *         _outgoingDataBuffer;
}

@property (nonatomic, retain) id<BSBonjourConnectionDelegate> delegate;

- (id) initWithNativeSocketHandle:(CFSocketNativeHandle)nativeSocketHandle;
- (id) initWithNetService:(NSNetService *)netService;

- (BOOL) connect;
- (void) close;

- (void) sendData:(NSData *)data;

@end
