/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBDevice.h"
#import "FBDevice+Private.h"

#import <XCTestBootstrap/XCTestBootstrap.h>

#import <FBControlCore/FBControlCore.h>

#import "FBAMDevice.h"
#import "FBDeviceApplicationCommands.h"
#import "FBDeviceApplicationDataCommands.h"
#import "FBDeviceControlError.h"
#import "FBDeviceCrashLogCommands.h"
#import "FBDeviceLogCommands.h"
#import "FBDeviceScreenshotCommands.h"
#import "FBDeviceSet+Private.h"
#import "FBDeviceVideoRecordingCommands.h"
#import "FBDeviceXCTestCommands.h"
#import "FBiOSDeviceOperator.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation FBDevice

@synthesize deviceOperator = _deviceOperator;
@synthesize logger = _logger;

#pragma mark Initializers

- (instancetype)initWithSet:(FBDeviceSet *)set amDevice:(FBAMDevice *)amDevice logger:(id<FBControlCoreLogger>)logger
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _set = set;
  _amDevice = amDevice;
  _logger = [logger withName:amDevice.udid];
  _forwarder = [FBiOSTargetCommandForwarder forwarderWithTarget:self commandClasses:FBDevice.commandResponders statefulCommands:FBDevice.statefulCommands];

  return self;
}

#pragma mark FBiOSTarget

- (NSArray<Class> *)actionClasses
{
  return @[
    FBTestLaunchConfiguration.class,
  ];
}

- (NSString *)udid
{
  return self.amDevice.udid;
}

- (NSString *)name
{
  return self.amDevice.deviceName;
}

- (FBArchitecture)architecture
{
  return self.amDevice.architecture;
}

- (NSString *)auxillaryDirectory
{
  return NSFileManager.defaultManager.currentDirectoryPath;
}

- (FBiOSTargetState)state
{
  return FBiOSTargetStateBooted;
}

- (FBiOSTargetType)targetType
{
  return FBiOSTargetTypeDevice;
}

- (FBProcessInfo *)containerApplication
{
  return nil;
}

- (FBProcessInfo *)launchdProcess
{
  return nil;
}

- (FBDeviceType *)deviceType
{
  return self.amDevice.deviceConfiguration;
}

- (FBOSVersion *)osVersion
{
  return self.amDevice.osConfiguration;
}

- (FBiOSTargetDiagnostics *)diagnostics
{
  return [[FBiOSTargetDiagnostics alloc] initWithStorageDirectory:self.auxillaryDirectory];
}

- (dispatch_queue_t)workQueue
{
  return dispatch_get_main_queue();
}

- (dispatch_queue_t)asyncQueue
{
  return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
}

- (NSComparisonResult)compare:(id<FBiOSTarget>)target
{
  return FBiOSTargetComparison(self, target);
}

#pragma mark FBDebugDescribeable

- (NSString *)description
{
  return [self debugDescription];
}

- (NSString *)debugDescription
{
  return [FBiOSTargetFormat.fullFormat format:self];
}

- (NSString *)shortDescription
{
  return [FBiOSTargetFormat.defaultFormat format:self];
}

#pragma mark FBJSONSerializable

- (NSDictionary *)jsonSerializableRepresentation
{
  return [FBiOSTargetFormat.fullFormat extractFrom:self];
}

#pragma mark Public

+ (NSOperatingSystemVersion)operatingSystemVersionFromString:(NSString *)string
{
  NSArray<NSString *> *components = [string componentsSeparatedByCharactersInSet:NSCharacterSet.punctuationCharacterSet];
  NSOperatingSystemVersion version = {
    .majorVersion = 0,
    .minorVersion = 0,
    .patchVersion = 0,
  };
  for (NSUInteger index = 0; index < components.count; index++) {
    NSInteger value = components[index].integerValue;
    switch (index) {
      case 0:
        version.majorVersion = value;
        continue;
      case 1:
        version.minorVersion = value;
        continue;
      case 2:
        version.patchVersion = value;
        continue;
      default:
        continue;
    }
  }
  return version;
}

#pragma mark Properties

- (id<FBDeviceOperator>)deviceOperator
{
  if (_deviceOperator == nil) {
    _deviceOperator = [FBiOSDeviceOperator forDevice:self];
  }
  return _deviceOperator;
}

- (NSString *)modelName
{
  return self.amDevice.modelName;
}

- (NSString *)productVersion
{
  return self.amDevice.productVersion;
}

- (NSString *)buildVersion
{
  return self.amDevice.buildVersion;
}

- (NSOperatingSystemVersion)operatingSystemVersion
{
  return [FBDevice operatingSystemVersionFromString:self.productVersion];
}

- (FBiOSTargetScreenInfo *)screenInfo
{
  return nil;
}

#pragma mark Forwarding

+ (NSArray<Class> *)commandResponders
{
  static dispatch_once_t onceToken;
  static NSArray<Class> *commandClasses;
  dispatch_once(&onceToken, ^{
    commandClasses = @[
      FBDeviceApplicationCommands.class,
      FBDeviceApplicationDataCommands.class,
      FBDeviceCrashLogCommands.class,
      FBDeviceLogCommands.class,
      FBDeviceScreenshotCommands.class,
      FBDeviceVideoRecordingCommands.class,
      FBDeviceXCTestCommands.class,
    ];
  });
  return commandClasses;
}

+ (NSSet<Class> *)statefulCommands
{
  // All commands are stateful
  return [NSSet setWithArray:self.commandResponders];
}

- (id)forwardingTargetForSelector:(SEL)selector
{
  // Try the forwarder.
  id command = [self.forwarder forwardingTargetForSelector:selector];
  if (command) {
    return command;
  }
  // Otherwise try the operator
  if ([FBiOSDeviceOperator instancesRespondToSelector:selector]) {
    return self.deviceOperator;
  }
  // Nothing left.
  return [super forwardingTargetForSelector:selector];
}

- (BOOL)conformsToProtocol:(Protocol *)protocol
{
  if ([super conformsToProtocol:protocol]) {
    return YES;
  }
  if ([self.forwarder conformsToProtocol:protocol]) {
    return  YES;
  }

  return NO;
}

@end

#pragma clang diagnostic pop
