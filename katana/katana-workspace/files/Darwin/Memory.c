/*
    KSysGuard, the KDE System Guard

    Copyright (c) 1999-2000 Hans Petter Bieker <bieker@kde.org>
    Copyright (c) 1999 Chris Schlaeger <cs@kde.org>
    Copyright (c) 2025 macOS port

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

*/

#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>

#include <mach/mach_init.h>
#include <mach/mach_host.h>
#include <mach/host_info.h>
#include <mach/vm_statistics.h>

#include "Command.h"
#include "Memory.h"
#include "ksysguardd.h"

static size_t Total = 0;
static size_t MFree = 0;
static size_t Used = 0;
static size_t Active = 0;
static size_t Inactive = 0;
static size_t Wired = 0;
static size_t STotal = 0;
static size_t SFree = 0;
static size_t SUsed = 0;
static size_t Application = 0;

void initMemory(struct SensorModul* sm)
{
    registerMonitor("mem/physical/free", "integer", printMFree, printMFreeInfo, sm);
    registerMonitor("mem/physical/used", "integer", printUsed, printUsedInfo, sm);
    registerMonitor("mem/physical/active", "integer", printActive, printActiveInfo, sm);
    registerMonitor("mem/physical/inactive", "integer", printInactive, printInactiveInfo, sm);
    registerMonitor("mem/physical/wired", "integer", printWired, printWiredInfo, sm);
    registerMonitor("mem/physical/application", "integer", printApplication, printApplicationInfo, sm);
    registerMonitor("mem/swap/free", "integer", printSwapFree, printSwapFreeInfo, sm);
    registerMonitor("mem/swap/used", "integer", printSwapUsed, printSwapUsedInfo, sm);
}

void exitMemory(void)
{
}

int updateMemory(void)
{
    vm_statistics_data_t vm_info;
    mach_msg_type_number_t info_count;
    DIR *dirp;
    struct dirent *dp;
    int mib[2];
    size_t len;

    /* Get physical memory total
     * Try HW_MEMSIZE first (Mac OS X 10.6+, returns 64-bit value)
     * Fall back to HW_PHYSMEM (Mac OS X 10.5 and earlier, returns 32-bit value)
     * This ensures compatibility with PowerPC Macs running 10.5 Leopard
     */
    mib[0] = CTL_HW;

#if defined(HW_MEMSIZE)
    /* 64-bit memory size - try this first on systems that support it */
    {
        uint64_t memsize64 = 0;
        mib[1] = HW_MEMSIZE;
        len = sizeof(memsize64);
        if (sysctl(mib, 2, &memsize64, &len, NULL, 0) == 0) {
            Total = (size_t)(memsize64 >> 10); /* Convert to KB */
        } else
#endif
        {
            /* Fall back to 32-bit HW_PHYSMEM for 10.5 and PowerPC compatibility */
            unsigned int memsize32 = 0;
            mib[1] = HW_PHYSMEM;
            len = sizeof(memsize32);
            if (sysctl(mib, 2, &memsize32, &len, NULL, 0) == 0) {
                Total = (size_t)(memsize32 >> 10); /* Convert to KB */
            } else {
                return -1;
            }
        }
#if defined(HW_MEMSIZE)
    }
#endif

    /* Get VM statistics using 32-bit vm_statistics_data_t
     * This is compatible with both PowerPC (32-bit) and Intel (64-bit)
     * The 64-bit variant (vm_statistics64) is not needed and less portable
     */
    info_count = HOST_VM_INFO_COUNT;
    if (host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vm_info, &info_count) != KERN_SUCCESS) {
        return -1;
    }

    /* Calculate memory statistics
     * vm_page_size is a global variable provided by Mach
     * All counters are in pages, we convert to KB for consistency
     */
    Active = (size_t)((vm_info.active_count * (unsigned long long)vm_page_size) >> 10);
    Inactive = (size_t)((vm_info.inactive_count * (unsigned long long)vm_page_size) >> 10);
    Wired = (size_t)((vm_info.wire_count * (unsigned long long)vm_page_size) >> 10);
    MFree = (size_t)((vm_info.free_count * (unsigned long long)vm_page_size) >> 10);

    Used = Active + Inactive + Wired;
    Application = Active + Inactive;

    /* Calculate swap space by scanning swap files
     * macOS creates dynamic swap files in /private/var/vm/
     * This approach works on both 10.5 PowerPC and newer systems
     */
    STotal = 0;
    dirp = opendir("/private/var/vm");
    if (dirp) {
        while ((dp = readdir(dirp)) != NULL) {
            struct stat sb;
            char fname[PATH_MAX];

            if (strncmp(dp->d_name, "swapfile", 8))
                continue;

            snprintf(fname, sizeof(fname), "/private/var/vm/%s", dp->d_name);
            if (stat(fname, &sb) == 0) {
                /* Use unsigned long long for size calculation to avoid overflow on large files */
                STotal += (size_t)((unsigned long long)sb.st_size >> 10); /* Convert to KB */
            }
        }
        closedir(dirp);
    }

    /* Free swap is not easily available on macOS without additional APIs
     * Conservative estimate: assume all swap is used
     */
    SUsed = STotal;
    SFree = 0;

    return 0;
}

void printMFree(const char* cmd)
{
    fprintf(CurrentClient, "%ld\n", (long)MFree);
}

void printMFreeInfo(const char* cmd)
{
    fprintf(CurrentClient, "Free Memory\t0\t%ld\tKB\n", (long)Total);
}

void printUsed(const char* cmd)
{
    fprintf(CurrentClient, "%ld\n", (long)Used);
}

void printUsedInfo(const char* cmd)
{
    fprintf(CurrentClient, "Used Memory\t0\t%ld\tKB\n", (long)Total);
}

void printActive(const char* cmd)
{
    fprintf(CurrentClient, "%ld\n", (long)Active);
}

void printActiveInfo(const char* cmd)
{
    fprintf(CurrentClient, "Active Memory\t0\t%ld\tKB\n", (long)Total);
}

void printInactive(const char* cmd)
{
    fprintf(CurrentClient, "%ld\n", (long)Inactive);
}

void printInactiveInfo(const char* cmd)
{
    fprintf(CurrentClient, "Inactive Memory\t0\t%ld\tKB\n", (long)Total);
}

void printWired(const char* cmd)
{
    fprintf(CurrentClient, "%ld\n", (long)Wired);
}

void printWiredInfo(const char* cmd)
{
    fprintf(CurrentClient, "Wired Memory\t0\t%ld\tKB\n", (long)Total);
}

void printApplication(const char* cmd)
{
    fprintf(CurrentClient, "%ld\n", (long)Application);
}

void printApplicationInfo(const char* cmd)
{
    fprintf(CurrentClient, "Application Memory\t0\t%ld\tKB\n", (long)Total);
}

void printSwapUsed(const char* cmd)
{
    fprintf(CurrentClient, "%ld\n", (long)SUsed);
}

void printSwapUsedInfo(const char* cmd)
{
    fprintf(CurrentClient, "Used Swap Memory\t0\t%ld\tKB\n", (long)STotal);
}

void printSwapFree(const char* cmd)
{
    fprintf(CurrentClient, "%ld\n", (long)SFree);
}

void printSwapFreeInfo(const char* cmd)
{
    fprintf(CurrentClient, "Free Swap Memory\t0\t%ld\tKB\n", (long)STotal);
}
