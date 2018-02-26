//
//  NESEmulatorBridge.h
//  NESDeltaCore
//
//  Created by Riley Testut on 2/25/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <DeltaCore/DeltaCore.h>
#import <DeltaCore/DeltaCore-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface NESEmulatorBridge : NSObject <DLTAEmulatorBridging>

@property (class, nonatomic, readonly) NESEmulatorBridge *sharedBridge;

@end

NS_ASSUME_NONNULL_END
