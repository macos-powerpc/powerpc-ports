// Copyright 2015 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Application that finds all Xcodes installed on a given Mac and will return
// a path for a given version number.
//
// This version is compatible with macOS 10.6+ and GCC.
// It uses directory scanning instead of Launch Services APIs
// that are not available on older macOS versions.

// Note: This file uses manual reference counting (MRC) for compatibility
// with GCC and older macOS versions. When building with clang and ARC,
// the retain/release calls are harmless (though redundant).

#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>

// Simple data structure for tracking a version of Xcode (i.e. 6.4) with an URL
// to the application.
@interface XcodeVersionEntry : NSObject {
  NSString *_version;
  NSURL *_url;
}
@property(readonly) NSString *version;
@property(readonly) NSURL *url;
- (id)initWithVersion:(NSString *)version url:(NSURL *)url;
@end

@implementation XcodeVersionEntry

@synthesize version = _version;
@synthesize url = _url;

- (void)dealloc {
  [_version release];
  [_url release];
  [super dealloc];
}

- (id)initWithVersion:(NSString *)version url:(NSURL *)url {
  if ((self = [super init])) {
    _version = [version retain];
    _url = [url retain];
  }
  return self;
}

- (id)description {
  return [NSString stringWithFormat:@"<%@ %p>: %@ %@",
                                    [self class], self, _version, _url];
}

@end

// Given an entry, insert it into a dictionary that is keyed by versions.
static void AddEntryToDictionary(XcodeVersionEntry *entry,
                                 NSMutableDictionary *dict) {
  BOOL inApplications = [[[entry url] path] hasPrefix:@"/Applications/"];
  NSString *entryVersion = [entry version];
  NSString *subversion = entryVersion;
  if ([dict objectForKey:entryVersion] && !inApplications) {
    return;
  }
  [dict setObject:entry forKey:entryVersion];
  while (YES) {
    NSRange range = [subversion rangeOfString:@"." options:NSBackwardsSearch];
    if (range.length == 0 || range.location == 0) {
      break;
    }
    subversion = [subversion substringToIndex:range.location];
    XcodeVersionEntry *subversionEntry = [dict objectForKey:subversion];
    if (subversionEntry) {
      BOOL atLeastAsLarge =
          ([[subversionEntry version] compare:[entry version]] ==
           NSOrderedDescending);
      if (inApplications && atLeastAsLarge) {
        [dict setObject:entry forKey:subversion];
      }
    } else {
      [dict setObject:entry forKey:subversion];
    }
  }
}

// Given a "version", expand it to at least 3 components by adding .0 as
// necessary.
static NSString *ExpandVersion(NSString *version) {
  NSArray *components = [version componentsSeparatedByString:@"."];
  NSString *appendage = nil;
  if ([components count] == 2) {
    appendage = @".0";
  } else if ([components count] == 1) {
    appendage = @".0.0";
  }
  if (appendage) {
    version = [version stringByAppendingString:appendage];
  }
  return version;
}

// Try to add an Xcode installation from a given path
static void TryAddXcodeAtPath(NSString *path, NSMutableDictionary *dict) {
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL isDir = NO;

  if (![fm fileExistsAtPath:path isDirectory:&isDir] || !isDir) {
    return;
  }

  NSBundle *bundle = [NSBundle bundleWithPath:path];
  if (bundle == nil) {
    return;
  }

  NSString *bundleID = [bundle bundleIdentifier];
  if (bundleID == nil ||
      (![bundleID isEqualToString:@"com.apple.dt.Xcode"] &&
       ![bundleID isEqualToString:@"com.apple.Xcode"])) {
    return;
  }

  NSString *versionKey = @"CFBundleShortVersionString";
  NSString *version = [[bundle infoDictionary] objectForKey:versionKey];
  if (version == nil) {
    return;
  }

  NSString *expandedVersion = ExpandVersion(version);

  // Try to get build version from version.plist
  NSString *versionPlistPath =
      [path stringByAppendingPathComponent:@"Contents/version.plist"];
  NSDictionary *versionPlist =
      [NSDictionary dictionaryWithContentsOfFile:versionPlistPath];
  if (versionPlist) {
    NSString *productVersion =
        [versionPlist objectForKey:@"ProductBuildVersion"];
    if (productVersion) {
      expandedVersion =
          [expandedVersion stringByAppendingFormat:@".%@", productVersion];
    }
  }

  // Developer dir is Contents/Developer for modern Xcode, or just the path
  // for old /Developer
  NSString *developerPath;
  NSString *contentsDevPath =
      [path stringByAppendingPathComponent:@"Contents/Developer"];
  if ([fm fileExistsAtPath:contentsDevPath isDirectory:&isDir] && isDir) {
    developerPath = contentsDevPath;
  } else {
    developerPath = path;
  }

  NSURL *developerURL = [NSURL fileURLWithPath:developerPath];
  XcodeVersionEntry *entry =
      [[[XcodeVersionEntry alloc] initWithVersion:expandedVersion
                                              url:developerURL] autorelease];
  AddEntryToDictionary(entry, dict);
}

// Searches for all available Xcodes in the system and returns a dictionary
// that maps version identifiers of any form (X, X.Y, and X.Y.Z) to the
// directory where the Xcode bundle lives.
static NSMutableDictionary *FindXcodes(void) {
  NSMutableDictionary *dict =
      [[[NSMutableDictionary alloc] init] autorelease];
  NSFileManager *fm = [NSFileManager defaultManager];

  // Check legacy /Developer path (Xcode 3.x and earlier)
  TryAddXcodeAtPath(@"/Developer", dict);

  // Check /Applications for Xcode*.app bundles
  NSArray *appsContents =
      [fm contentsOfDirectoryAtPath:@"/Applications" error:nil];
  if (appsContents) {
    NSEnumerator *enumerator = [appsContents objectEnumerator];
    NSString *item;
    while ((item = [enumerator nextObject])) {
      if ([item hasPrefix:@"Xcode"] && [item hasSuffix:@".app"]) {
        NSString *fullPath =
            [@"/Applications" stringByAppendingPathComponent:item];
        TryAddXcodeAtPath(fullPath, dict);
      }
    }
  }

  // Also check user Applications folder
  NSString *userApps = [@"~/Applications" stringByExpandingTildeInPath];
  NSArray *userAppsContents =
      [fm contentsOfDirectoryAtPath:userApps error:nil];
  if (userAppsContents) {
    NSEnumerator *enumerator = [userAppsContents objectEnumerator];
    NSString *item;
    while ((item = [enumerator nextObject])) {
      if ([item hasPrefix:@"Xcode"] && [item hasSuffix:@".app"]) {
        NSString *fullPath = [userApps stringByAppendingPathComponent:item];
        TryAddXcodeAtPath(fullPath, dict);
      }
    }
  }

  return dict;
}

// Prints out the located Xcodes as a set of lines where each line contains
// the list of versions for a given Xcode and its location on disk.
static void DumpAsVersionsOnly(FILE *output, NSMutableDictionary *dict) {
  NSMutableDictionary *aliasDict =
      [[[NSMutableDictionary alloc] init] autorelease];

  NSEnumerator *keyEnum = [dict keyEnumerator];
  NSString *aliasVersion;
  while ((aliasVersion = [keyEnum nextObject])) {
    XcodeVersionEntry *entry = [dict objectForKey:aliasVersion];
    NSString *versionString = [entry version];
    if ([aliasDict objectForKey:versionString] == nil) {
      [aliasDict setObject:[NSMutableSet set] forKey:versionString];
    }
    [[aliasDict objectForKey:versionString] addObject:aliasVersion];
  }

  keyEnum = [aliasDict keyEnumerator];
  NSString *version;
  while ((version = [keyEnum nextObject])) {
    XcodeVersionEntry *entry = [dict objectForKey:version];
    fprintf(output, "%s:%s:%s\n", [version UTF8String],
            [[[[aliasDict objectForKey:version] allObjects]
                componentsJoinedByString:@","] UTF8String],
            [[[entry url] path] UTF8String]);
  }
}

// Prints out the located Xcodes in JSON format.
static void DumpAsJson(FILE *output, NSMutableDictionary *dict) {
  fprintf(output, "{\n");
  NSEnumerator *keyEnum = [dict keyEnumerator];
  NSString *version;
  while ((version = [keyEnum nextObject])) {
    XcodeVersionEntry *entry = [dict objectForKey:version];
    fprintf(output, "\t\"%s\": \"%s\",\n", [version UTF8String],
            [[[entry url] path] UTF8String]);
  }
  fprintf(output, "}\n");
}

// Dumps usage information.
static void usage(FILE *output) {
  fprintf(output,
          "xcode-locator [-v|<version_number>]"
          "\n\n"
          "Given a version number or partial version number in x.y.z format, "
          "will attempt to return the path to the appropriate developer "
          "directory."
          "\n\n"
          "Omitting a version number will list all available versions in JSON "
          "format, alongside their paths."
          "\n\n"
          "Passing -v will list all available fully-specified version numbers "
          "along with their possible aliases and their developer directory, "
          "each on a new line. For example:"
          "\n\n"
          "7.3.1:7,7.3,7.3.1:/Applications/Xcode.app/Contents/Developer"
          "\n");
}

int main(int argc, const char *argv[]) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  int exitCode = 0;

  NSString *versionArg = nil;
  BOOL versionsOnly = NO;
  if (argc == 1) {
    versionArg = @"";
  } else if (argc == 2) {
    NSString *firstArg = [NSString stringWithUTF8String:argv[1]];
    if ([@"-v" isEqualToString:firstArg]) {
      versionsOnly = YES;
      versionArg = @"";
    } else {
      versionArg = firstArg;
    }
  }

  if (versionArg == nil) {
    usage(stderr);
    exitCode = 1;
  } else {
    NSMutableDictionary *dict = FindXcodes();

    XcodeVersionEntry *entry = [dict objectForKey:versionArg];
    if (entry) {
      printf("%s\n", [[[entry url] path] UTF8String]);
      exitCode = 0;
    } else if (versionsOnly) {
      DumpAsVersionsOnly(stdout, dict);
      exitCode = 0;
    } else if ([@"" isEqualToString:versionArg]) {
      DumpAsJson(stdout, dict);
      exitCode = 0;
    } else {
      exitCode = 1;
    }
  }

  [pool release];
  return exitCode;
}
