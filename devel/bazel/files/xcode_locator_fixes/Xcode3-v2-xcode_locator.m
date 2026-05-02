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

// Stub xcode-locator for macOS 10.6+ and GCC compatibility.
// This version does not find any Xcode installations.
// MacPorts uses its own compiler toolchain, so Xcode detection is unnecessary.

#import <Foundation/Foundation.h>

// Prints out empty JSON.
static void DumpAsJson(FILE *output) {
  fprintf(output, "{\n}\n");
}

// Dumps usage information.
static void usage(FILE *output) {
  fprintf(
      output,
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
      NSCharacterSet *versSet =
          [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];
      if ([versionArg rangeOfCharacterFromSet:[versSet invertedSet]].length !=
          0) {
        versionArg = nil;
      }
    }
  }

  if (versionArg == nil) {
    usage(stderr);
    [pool release];
    return 1;
  }

  // Stub: we don't find any Xcodes. MacPorts toolchain is used instead.
  if (versionsOnly) {
    // Output nothing for -v
  } else if ([@"" isEqualToString:versionArg]) {
    DumpAsJson(stdout);
  }

  [pool release];
  return ([@"" isEqualToString:versionArg] ? 0 : 1);
}
