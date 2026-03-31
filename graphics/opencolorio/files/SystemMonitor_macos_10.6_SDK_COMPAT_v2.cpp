// SPDX-License-Identifier: BSD-3-Clause
// Copyright Contributors to the OpenColorIO Project.
// Modified for macOS 10.6 SDK compatibility

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <iostream>
#include <sstream>
#include <vector>

namespace OpenColorIO_v2_5
{

namespace
{

std::string GetICCProfilePath(CGDirectDisplayID dispId)
{
    // For macOS 10.6, use deprecated ColorSync Manager APIs
    // CGColorSpaceCopyICCData() doesn't exist in 10.6

    // Get the color space for the display
    CGColorSpaceRef colorSpace = CGDisplayCopyColorSpace(dispId);
    if (!colorSpace)
    {
        return "";
    }

    std::string profilePath;

    // Method 1: Try to get profile using ColorSync Manager
    // Get the display's ColorSync profile reference
    CMProfileRef cmProfile = nullptr;

    // For 10.6, we need to use the deprecated CMGetProfileByAVID
    // which gets a profile by Apple Video ID (which is the display ID)
    CMError err = CMGetProfileByAVID((CMDisplayIDType)dispId, &cmProfile);

    if (err == noErr && cmProfile != nullptr)
    {
        // Get the profile location (path)
        CMProfileLocation profileLoc;
        UInt32 locationSize = sizeof(CMProfileLocation);

        err = CMGetProfileLocation(cmProfile, &profileLoc, &locationSize);

        if (err == noErr)
        {
            if (profileLoc.locType == cmPathBasedProfile)
            {
                // Extract path from FSSpec or path-based location
                // In 10.6, cmPathBasedProfile uses FSSpec
                char pathBuffer[PATH_MAX];
                FSSpec *fsSpec = &profileLoc.u.pathLoc.fileSpec;

                // Convert FSSpec to path
                FSRef fsRef;
                err = FSpMakeFSRef(fsSpec, &fsRef);
                if (err == noErr)
                {
                    err = FSRefMakePath(&fsRef, (UInt8*)pathBuffer, PATH_MAX);
                    if (err == noErr)
                    {
                        profilePath = std::string(pathBuffer);
                    }
                }
            }
            else if (profileLoc.locType == cmFileBasedProfile)
            {
                // Handle file-based profile (FSSpec-based in 10.6)
                char pathBuffer[PATH_MAX];
                FSRef fsRef;

                err = FSpMakeFSRef(&profileLoc.u.fileLoc.spec, &fsRef);
                if (err == noErr)
                {
                    err = FSRefMakePath(&fsRef, (UInt8*)pathBuffer, PATH_MAX);
                    if (err == noErr)
                    {
                        profilePath = std::string(pathBuffer);
                    }
                }
            }
        }

        CMCloseProfile(cmProfile);
    }

    CGColorSpaceRelease(colorSpace);

    return profilePath;
}

} // namespace

std::string GetCurrentMonitorProfilePath()
{
    // Get the main display
    CGDirectDisplayID displayId = CGMainDisplayID();

    std::string path = GetICCProfilePath(displayId);

    if (path.empty())
    {
        // Fallback: try to get the generic RGB profile path
        // This is a reasonable default for 10.6
        path = "/System/Library/ColorSync/Profiles/sRGB Profile.icc";
    }

    return path;
}

std::vector<std::string> GetActiveMonitorProfiles()
{
    std::vector<std::string> profiles;

    // Get all active displays
    CGDirectDisplayID displays[32];
    uint32_t numDisplays = 0;

    CGError err = CGGetActiveDisplayList(32, displays, &numDisplays);

    if (err == kCGErrorSuccess)
    {
        for (uint32_t i = 0; i < numDisplays; ++i)
        {
            std::string path = GetICCProfilePath(displays[i]);
            if (!path.empty())
            {
                profiles.push_back(path);
            }
        }
    }

    // If no profiles found, add default sRGB
    if (profiles.empty())
    {
        profiles.push_back("/System/Library/ColorSync/Profiles/sRGB Profile.icc");
    }

    return profiles;
}

std::string GetMonitorDescription(const std::string & monitorProfilePath)
{
    if (monitorProfilePath.empty())
    {
        return "";
    }

    std::string description;

    // Open the ICC profile from file path
    CMProfileLocation loc;
    loc.locType = cmPathBasedProfile;

    // For 10.6, we need to convert path to FSSpec
    FSRef fsRef;
    OSStatus status = FSPathMakeRef((const UInt8*)monitorProfilePath.c_str(), &fsRef, nullptr);

    if (status == noErr)
    {
        FSSpec fsSpec;
        status = FSGetCatalogInfo(&fsRef, kFSCatInfoNone, nullptr, nullptr, &fsSpec, nullptr);

        if (status == noErr)
        {
            loc.u.pathLoc.fileSpec = fsSpec;

            CMProfileRef profile = nullptr;
            CMError err = CMOpenProfile(&profile, &loc);

            if (err == noErr && profile != nullptr)
            {
                // Get profile description
                Str255 descriptionStr;
                err = CMGetProfileDescriptionString(profile, descriptionStr);

                if (err == noErr)
                {
                    // Convert Pascal string to C++ string
                    // Pascal string: first byte is length, rest is string data
                    UInt8 len = descriptionStr[0];
                    if (len > 0)
                    {
                        description = std::string((char*)&descriptionStr[1], len);
                    }
                }

                CMCloseProfile(profile);
            }
        }
    }

    if (description.empty())
    {
        // Fallback: extract filename from path
        size_t lastSlash = monitorProfilePath.find_last_of('/');
        if (lastSlash != std::string::npos)
        {
            description = monitorProfilePath.substr(lastSlash + 1);
        }
        else
        {
            description = monitorProfilePath;
        }
    }

    return description;
}

} // namespace OpenColorIO_v2_5
