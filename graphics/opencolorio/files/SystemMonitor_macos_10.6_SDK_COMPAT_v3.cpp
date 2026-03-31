// SPDX-License-Identifier: BSD-3-Clause
// Copyright Contributors to the OpenColorIO Project.
// Modified for macOS 10.6 SDK compatibility - v3

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

    // Get the color space for the display
    CGColorSpaceRef colorSpace = CGDisplayCopyColorSpace(dispId);
    if (!colorSpace)
    {
        return "";
    }

    std::string profilePath;

    // Get the display's ColorSync profile reference using deprecated API
    CMProfileRef cmProfile = nullptr;

    // CMGetProfileByAVID gets a profile by Apple Video ID (display ID)
    CMError err = CMGetProfileByAVID((CMDisplayIDType)dispId, &cmProfile);

    if (err == noErr && cmProfile != nullptr)
    {
        // Get the profile location (path)
        CMProfileLocation profileLoc;

        // In 10.6, CMGetProfileLocation takes only 2 arguments
        err = CMGetProfileLocation(cmProfile, &profileLoc);

        if (err == noErr)
        {
            // In 10.6, CMProfileLocation uses different union members
            if (profileLoc.locType == cmFileBasedProfile)
            {
                // File-based profile uses FSSpec
                char pathBuffer[PATH_MAX];
                FSRef fsRef;

                // Convert FSSpec to FSRef, then to path
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
    loc.locType = cmFileBasedProfile;

    // For 10.6, we need to convert path to FSSpec
    FSRef fsRef;
    OSStatus status = FSPathMakeRef((const UInt8*)monitorProfilePath.c_str(), &fsRef, nullptr);

    if (status == noErr)
    {
        // Convert FSRef to FSSpec (10.6 way)
        status = FSGetCatalogInfo(&fsRef, kFSCatInfoNone, nullptr, nullptr, &loc.u.fileLoc.spec, nullptr);

        if (status == noErr)
        {
            CMProfileRef profile = nullptr;
            CMError err = CMOpenProfile(&profile, &loc);

            if (err == noErr && profile != nullptr)
            {
                // In 10.6, use CMCopyProfileDescriptionString (not CMGetProfileDescriptionString)
                CFStringRef descriptionCF = nullptr;
                err = CMCopyProfileDescriptionString(profile, &descriptionCF);

                if (err == noErr && descriptionCF != nullptr)
                {
                    // Convert CFString to C++ string
                    char buffer[256];
                    if (CFStringGetCString(descriptionCF, buffer, sizeof(buffer), kCFStringEncodingUTF8))
                    {
                        description = std::string(buffer);
                    }
                    CFRelease(descriptionCF);
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
