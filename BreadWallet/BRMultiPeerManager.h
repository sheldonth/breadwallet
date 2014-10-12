//
//  BRMultiPeerManager.h
//  BreadWallet
//
//  Created by Sheldon Thomas on 9/20/14.
//  Copyright (c) 2014 Aaron Voisine. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#ifdef MULTIPEER

#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

#define BROWSES YES
#define DEFAULT_PEER_NAME @"Peer"
#define SERVICE_TYPE @"bitcoin" // Must be 1–15 characters long Can contain only ASCII lowercase letters, numbers, and hyphens. (Per docs)
#define SERVICES_KEY @"bitcoinservices"
#define PEER_COUNT_KEY @"peercount"
#define ADDRESS_KEY @"addr"
#define DISPLAY_NAME_KEY @"displayname"
#define TIME_ENCOUNTERED_KEY @"time"
#define MINIMUM_PEERS 0
#define MAXIMUM_PEERS 10

#define BRMultiPeerManagerNewPeerCountNofication @"BRMultiPeerManagerNewPeerCountNofication"

@class BRMultiPeerManager;

@interface BRMultiPeerManager : NSObject

- (instancetype)newPeerName;
- (void)startAdvertisingWithCompletion:(void (^)(void))completion;
- (void)stopAdvertisingWithCompletion:(void (^)(void))completion;
- (void)startBrowsingWithCompletion:(void (^)(void))completion;

+ (instancetype)sharedInstance;

@property (nonatomic, strong) NSMutableOrderedSet *peers;

@property (nonatomic, strong, readonly) NSNumber *advertises;
@property (nonatomic, strong, readonly) MCPeerID *peerID;

@end

#endif
