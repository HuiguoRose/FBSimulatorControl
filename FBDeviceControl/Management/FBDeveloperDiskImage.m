/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBDeveloperDiskImage.h"

#import "FBDevice.h"
#import "FBDeviceControlError.h"

@implementation FBDeveloperDiskImage

#pragma mark Private

+ (NSString *)pathForDeviceSupportDirectory:(FBDevice *)device error:(NSError **)error
{
  NSArray<NSString *> *searchPaths = @[
    [FBXcodeConfiguration.developerDirectory stringByAppendingPathComponent:@"Platforms/iPhoneOS.platform/DeviceSupport"],
    [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/Xcode/iOS DeviceSupport"],
  ];

  NSString *buildVersion = device.buildVersion;
  NSOperatingSystemVersion targetVersion = device.operatingSystemVersion;
  for (NSString *searchPath in searchPaths) {
    for (NSString *fileName in [NSFileManager.defaultManager enumeratorAtPath:searchPath]) {
      NSString *path = [searchPath stringByAppendingPathComponent:fileName];
      if ([path containsString:buildVersion]) {
        return path;
      }
      NSOperatingSystemVersion currentVersion = [FBDevice operatingSystemVersionFromString:fileName];
      if (currentVersion.majorVersion == targetVersion.majorVersion && currentVersion.minorVersion == targetVersion.minorVersion) {
        return path;
      }
    }
  }
  return [[FBDeviceControlError
    describeFormat:@"Could not find the DeveloperDiskImage for %@", self]
    fail:error];
}

#pragma mark Initializers

+ (FBDeveloperDiskImage *)developerDiskImage:(FBDevice *)device error:(NSError **)error
{
  NSString *directory = [self pathForDeviceSupportDirectory:device error:error];
  if (!directory) {
    return nil;
  }
  NSString *diskImagePath = [directory stringByAppendingPathComponent:@"DeveloperDiskImage.dmg"];
  if (![NSFileManager.defaultManager fileExistsAtPath:diskImagePath]) {
    return [[FBDeviceControlError
      describeFormat:@"Disk image does not exist at expected path %@", diskImagePath]
      fail:error];
  }
  NSString *signaturePath = [diskImagePath stringByAppendingString:@".signature"];
  NSData *signature = [NSData dataWithContentsOfFile:signaturePath];
  if (!signature) {
    return [[FBDeviceControlError
      describeFormat:@"Failed to load signature at %@", signaturePath]
      fail:error];
  }
  return [[FBDeveloperDiskImage alloc] initWithDiskImagePath:diskImagePath signature:signature];
}

- (instancetype)initWithDiskImagePath:(NSString *)diskImagePath signature:(NSData *)signature
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _diskImagePath = diskImagePath;
  _signature = signature;

  return self;
}

@end
