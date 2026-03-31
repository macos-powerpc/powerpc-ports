// SPDX-License-Identifier: BSD-3-Clause
// Copyright Contributors to the OpenColorIO Project.
// Modified for macOS 10.6 SDK compatibility


#if !defined(__APPLE__)

#error The file is for the macOS platform only.

#endif


#include <ColorSync/ColorSync.h>
#include <CoreGraphics/CoreGraphics.h>
#include <IOKit/graphics/IOGraphicsLib.h>

#include "Logging.h"


namespace OCIO_NAMESPACE
{


static constexpr char ErrorMsg[] { "Problem obtaining monitor profile information from operating system." };


// Some variables must be released.
template<typename T>
struct Guard
{
    Guard() = delete;
    Guard(const Guard &) = delete;
    Guard & operator=(const Guard &) = delete;

    explicit Guard(T & data) : m_data(data) {}
    ~Guard() { release(); }

    void release()
    {
        if (!m_released)
        {
            if (m_data)
            {
                CFRelease(m_data);
            }
            m_released = true;
        }
    }

    T m_data;
    bool m_released = false;
};

std::string GetICCProfilePath(CGDirectDisplayID dispId)
{
    // macOS 10.6 compatibility:
    // Use deprecated ColorSync Manager API instead of modern ColorSync API
    // (CGDisplayCreateUUIDFromDisplayID and ColorSyncDeviceCopyDeviceInfo don't exist in 10.6)

    CMProfileRef cmProfile = nullptr;

    // Get the ColorSync profile for the display using deprecated API
    CMError err = CMGetProfileByAVID((CMDisplayIDType)dispId, &cmProfile);

    if (err != noErr || cmProfile == nullptr)
    {
        throw Exception(ErrorMsg);
    }

    // Get the profile location
    CMProfileLocation profileLoc;

    // In 10.6, CMGetProfileLocation takes only 2 parameters (not 3)
    err = CMGetProfileLocation(cmProfile, &profileLoc);

    if (err != noErr)
    {
        CMCloseProfile(cmProfile);
        throw Exception(ErrorMsg);
    }

    char path[PATH_MAX];
    bool gotPath = false;

    // In 10.6, profile locations use cmFileBasedProfile (not cmPathBasedProfile)
    if (profileLoc.locType == cmFileBasedProfile)
    {
        // Convert FSSpec to FSRef, then to POSIX path
        FSRef fsRef;
        OSStatus status = FSpMakeFSRef(&profileLoc.u.fileLoc.spec, &fsRef);

        if (status == noErr)
        {
            status = FSRefMakePath(&fsRef, (UInt8*)path, PATH_MAX);
            if (status == noErr)
            {
                gotPath = true;
            }
        }
    }

    CMCloseProfile(cmProfile);

    if (!gotPath)
    {
        throw Exception(ErrorMsg);
    }

    return std::string(path);
}

// Some references for 'Quartz Display Services' part of the 'Core Graphics' framework:
//  * https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Introduction/Introduction.html#//apple_ref/doc/uid/TP40004245-SW1
//  * https://developer.apple.com/documentation/coregraphics/quartz_display_services?language=objc

void SystemMonitorsImpl::getAllMonitors()
{
    m_monitors.clear();

    // TODO: Needs to have all displays with a status to indicate the active ones?

    // CGGetActiveDisplayList provides only the list of displays that are active (i.e. drawable).
    // Note: CGGetOnlineDisplayList provides the list of all displays that are online (active,
    // mirrored, or sleeping).

    // Get the number of active monitors.

    uint32_t maxDisplays = 0;
    CGDisplayErr err = CGGetActiveDisplayList(0, nullptr, &maxDisplays);
    if (err != kCGErrorSuccess)
    {
        throw Exception(ErrorMsg);
    }

    if (maxDisplays == 0)
    {
        // There is no active monitor.
        return;
    }

    std::vector<CGDirectDisplayID> displays(maxDisplays);
    uint32_t numDisplays = 0;

    // Get all the active monitors.

    err = CGGetActiveDisplayList(maxDisplays, &displays[0], &numDisplays);
    if ((err != kCGErrorSuccess) || (numDisplays != maxDisplays))
    {
        throw Exception(ErrorMsg);
    }

    // Get all active monitors.

    for (uint32_t idx = 0; idx < numDisplays; ++idx)
    {
        CGDirectDisplayID dispId = displays[idx];
        // Build a generic unique name if vendor information is not accessible.
        std::string displayName = "Monitor " + std::to_string(idx);

        CFDictionaryRef displayInfo
            = IODisplayCreateInfoDictionary(CGDisplayIOServicePort(dispId), kIODisplayOnlyPreferredName);
        Guard<CFDictionaryRef> info(displayInfo);

        if (!displayInfo)
        {
            // No way to log a meaningful error so continue.
            continue;
        }

        // Improve the display name if accessible.

        CFDictionaryRef productInfo
            = (CFDictionaryRef)CFDictionaryGetValue(displayInfo, CFSTR(kDisplayProductName));
        if (productInfo)
        {
            const CFIndex number = CFDictionaryGetCount(productInfo);
            if (number > 0)
            {
                std::vector<CFStringRef> values(number);
                CFDictionaryGetKeysAndValues(productInfo, nullptr, (const void **)&values[0]);

                const CFIndex bufferSize = CFStringGetLength(values[0]) + 1; // +1 for null termination
                std::vector<char> buffer(bufferSize);

                // Return false if the buffer is too small or if the conversion fails.
                if (CFStringGetCString(values[0], buffer.data(), buffer.size(), kCFStringEncodingUTF8))
                {
                    // Build a name using the vendor information.
                    displayName = buffer.data();

                    // Add the display unit number (i.e. identify the display's framebuffer)
                    // to differentiate same type of monitors.
                    displayName += ", id=" + std::to_string(CGDisplayUnitNumber(dispId));
                }
            }
        }

        try
        {
            const std::string iccFilepath = GetICCProfilePath(dispId);
            m_monitors.push_back({displayName, iccFilepath});
        }
        catch(const Exception & ex)
        {
            std::ostringstream oss;
            oss << "Failed to access ICC profile for the monitor '"
                << displayName << "': "
                << ex.what();

            LogDebug(oss.str());
        }
    }
}

} // namespace OCIO_NAMESPACE
