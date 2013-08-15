//
//  ZNKeySequence.h
//  ZincWallet
//
//  Created by Aaron Voisine on 5/27/13.
//  Copyright (c) 2013 zinc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SEED_LENGTH (128/8)
#define GAP_LIMIT_EXTERNAL 10
#define GAP_LIMIT_INTERNAL 3

@protocol ZNKeySequence <NSObject>
@required

- (NSData *)masterPublicKeyFromSeed:(NSData *)seed;
- (NSData *)publicKey:(NSUInteger)n internal:(BOOL)internal masterPublicKey:(NSData *)masterPublicKey;
- (NSString *)privateKey:(NSUInteger)n internal:(BOOL)internal fromSeed:(NSData *)seed;
- (NSArray *)privateKeys:(NSArray *)n internal:(BOOL)internal fromSeed:(NSData *)seed;

@end
