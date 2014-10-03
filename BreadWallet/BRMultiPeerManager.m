//
//  BRMultiPeerManager.m
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

#include <stdlib.h>

#import "BRMultiPeerManager.h"
#import "BRWalletManager.h"
#import "BRWallet.h"

#define NOISY_MULTIPEERMANAGER NO

typedef enum : uint16_t {
    BRMultiPeerServiceTypeBitcoinAddressAdvertiser = (1 << 0), // 00000001 => Only advertises recieving addresses, never joins a session
    BRMultiPeerServiceTypeBitcoinPaymentProtocol = (1 << 1), // 00000010 => For accepting, fufilling, and acknowledging bitcoin payment protocol objects. TODO
    BRMultiPeerServiceTypeBitcoinNetworkRelay = (1 << 2) // 00000100 => For relaying traffic to the bitcoin network if the other device has connectivity and this does not. TODO
}BRMultiPeerServiceType;

@interface BRMultiPeerManager() <MCSessionDelegate, MCAdvertiserAssistantDelegate, MCNearbyServiceBrowserDelegate>

@property (nonatomic) BRMultiPeerServiceType serviceType;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCAdvertiserAssistant *serviceAdvertiserAssistant;
@property (nonatomic, strong) MCNearbyServiceBrowser *nearbyServiceBrowser;
@property (nonatomic, strong) dispatch_queue_t q;
@property (nonatomic, strong) id seedChangeObserver;

@end

@implementation BRMultiPeerManager

#pragma mark - MCNearbyServiceBrowser

// Used for fully bidirectional sessions
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    // required delegate method but unused
}

// Received data from remote peer
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    // required delegate method but unused
}

// Received a byte stream from remote peer
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    // required delegate method but unused
}

// Start receiving a resource from remote peer
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    // required delegate method but unused
}


// Finished receiving a resource from remote peer and saved the content in a temporary location - the app is responsible for moving the file to a permanent location within its sandbox
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    if (NOISY_MULTIPEERMANAGER) NSLog(@"didFinishReceivingResourceWithName");
}

// Made first contact with peer and have identity information about the remote peer (certificate may be nil)
- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate fromPeer:(MCPeerID *)peerID certificateHandler:(void(^)(BOOL accept))certificateHandler
{
    if (NOISY_MULTIPEERMANAGER) NSLog(@"didReceiveCertificate");
}

/*
 Peer Sanity Test:
 
    1. Is this peer/address combo already in the peers
        if yes, return
    2. Are we currently advertising this same peer ID and address (the framework will give you a callback about yourself if you advertise and browse, :-| very annoying)
        if yes, return
    2.1 Is this person advertising our address (or any address in our wallet) with a different peer ID?
        if yes,
    3. Iis this person advertising
    3. Is the peer's ID XXXXXX (a 6 digit number?)
        if no, return
    4. Do we have a peer in peers with this ID but a different address?
        if yes, possible impersonation attack -- drop both the new peer ID and old peer ID
    5. Do we have a peer in peers with a different ID but this address?
        if yes, drop the peer with the old ID and add the new ID with the same address as the old one.
 */

// Found a nearby advertising peer
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    if (NOISY_MULTIPEERMANAGER) NSLog(@"MP Found: %@", peerID.displayName);
    
    if (![info objectForKey:ADDRESS_KEY])
        return;
    
    // sanity check 1
    NSIndexSet* s = [self.peers indexesOfObjectsPassingTest:^BOOL(NSDictionary* obj, NSUInteger idx, BOOL *stop) {
        if ([[obj objectForKey:ADDRESS_KEY]isEqualToString:[info objectForKey:ADDRESS_KEY]] && [[obj objectForKey:DISPLAY_NAME_KEY]isEqualToString:peerID.displayName])
            return YES;
        else
            return NO;
    }];
    if (s.count) return;
    
    // sanity check 2
    if ([[[BRWalletManager sharedInstance] wallet] receiveAddress])
        if ([self.peerID.displayName isEqualToString:peerID.displayName] && [[[[BRWalletManager sharedInstance] wallet] receiveAddress] isEqualToString:[info objectForKey:ADDRESS_KEY]])
            return;
    
    // sanity check 3
    if ([[peerID displayName]intValue] == 0 || [[peerID displayName]intValue] == INT_MAX || [[peerID displayName]intValue] == INT_MIN)
        return;
    
    // sanity check 4
    NSIndexSet* s1 = [self.peers indexesOfObjectsPassingTest:^BOOL(NSDictionary* obj, NSUInteger idx, BOOL *stop) {
        if ([[obj objectForKey:DISPLAY_NAME_KEY]isEqualToString:[peerID displayName]])
            return YES;
        else
            return NO;
    }];
    if (s1.count)
    {
        [self.peers removeObjectsAtIndexes:s1];
        [[NSNotificationCenter defaultCenter]postNotificationName:BRMultiPeerManagerNewPeerCountNofication object:nil userInfo:nil];
        return;
    }

    NSIndexSet* s2 = [self.peers indexesOfObjectsPassingTest:^BOOL(NSDictionary* obj, NSUInteger idx, BOOL *stop) {
        if ([[obj objectForKey:ADDRESS_KEY]isEqualToString:[info objectForKey:ADDRESS_KEY]])
            return YES;
        else
            return NO;
    }];
    if (s2.count)
        [self.peers removeObjectsAtIndexes:s2];
    // Add the new entry
    NSMutableDictionary* mutableInfoDictionary = [NSMutableDictionary dictionaryWithDictionary:info];
    [mutableInfoDictionary setObject:peerID.displayName forKey:DISPLAY_NAME_KEY];
    [mutableInfoDictionary setObject:[NSDate date] forKey:TIME_ENCOUNTERED_KEY];
    [self.peers addObject:mutableInfoDictionary];
    // Post notification
    [[NSNotificationCenter defaultCenter]postNotificationName:BRMultiPeerManagerNewPeerCountNofication object:nil userInfo:@{PEER_COUNT_KEY:@(self.peers.count)}];
}

// A nearby peer has stopped advertising
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    if (NOISY_MULTIPEERMANAGER) NSLog(@"MP lost %@", peerID.displayName);
    NSIndexSet *a = [self.peers indexesOfObjectsPassingTest:^BOOL(NSDictionary* obj, NSUInteger idx, BOOL *stop) {
        if ([[obj valueForKey:DISPLAY_NAME_KEY] isEqualToString:peerID.displayName])
            return YES;
        else
            return NO;
    }];
    [self.peers removeObjectsAtIndexes:a];
    [[NSNotificationCenter defaultCenter]postNotificationName:BRMultiPeerManagerNewPeerCountNofication object:nil userInfo:@{PEER_COUNT_KEY:@(self.peers.count)}];
}

// Browsing did not start due to an error
- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    if (NOISY_MULTIPEERMANAGER) NSLog(@"didNotStartBrowsingForPeers");
}

#pragma mark - BRMultiPeerManager

- (void)startAdvertisingWithCompletion:(void (^)(void))completion
{
    dispatch_async(self.q, ^{
        [self setServiceAdvertiserAssistant:[[MCAdvertiserAssistant alloc]initWithServiceType:SERVICE_TYPE discoveryInfo:@{SERVICES_KEY:@(self.serviceType).stringValue, ADDRESS_KEY:[[[BRWalletManager sharedInstance] wallet] receiveAddress]} session:self.session]];
        [self.serviceAdvertiserAssistant setDelegate:self];
        [self.serviceAdvertiserAssistant start];
        if (completion) dispatch_async(dispatch_get_main_queue(), completion);
    });
}

- (void)stopAdvertisingWithCompletion:(void (^)(void))completion
{
    dispatch_async(self.q, ^{
        [self.serviceAdvertiserAssistant stop];
        [self setServiceAdvertiserAssistant:nil];
        if (completion) dispatch_async(dispatch_get_main_queue(), completion);
    });
}

// never need to stop browsing
- (void)startBrowsingWithCompletion:(void (^)(void))completion
{
    dispatch_async(self.q, ^{
        [self setNearbyServiceBrowser:[[MCNearbyServiceBrowser alloc]initWithPeer:self.peerID serviceType:SERVICE_TYPE]];
        [self.nearbyServiceBrowser setDelegate:self];
        [self.nearbyServiceBrowser startBrowsingForPeers];
        if (completion) dispatch_async(dispatch_get_main_queue(), completion);
    });
}

- (instancetype)newPeerName
{
    _peerID = [[MCPeerID alloc]initWithDisplayName:[self newPeerNameString]];
    [self setSession:[[MCSession alloc]initWithPeer:self.peerID securityIdentity:nil encryptionPreference:MCEncryptionNone]];
    return self;
}

- (NSString* )newPeerNameString
{
    return [NSString stringWithFormat:@"%@", [@((arc4random() % 9000) + 1000) stringValue]];
}

- (instancetype)init
{
    if (! (self = [super init])) return nil;
    self.q = dispatch_queue_create("multipeermanager", NULL);
    [self setServiceType:(BRMultiPeerServiceTypeBitcoinAddressAdvertiser)]; // default, for now
//    [self setServiceType:(BRMultiPeerServiceTypeBitcoinAddressAdvertiser | BRMultiPeerServiceTypeBitcoinNetworkRelay)]; // 00000101  => how one would advertise multiple services
    [self setPeers:[NSMutableOrderedSet orderedSetWithCapacity:MAXIMUM_PEERS]];
    [self newPeerName];
    self.seedChangeObserver =
        [[NSNotificationCenter defaultCenter]addObserverForName:BRWalletManagerSeedChangedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            [self newPeerName];
        }];
    return self;
}

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

@end

#endif
