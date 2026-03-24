/*
    KSysGuard, the KDE System Guard

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

#include <sys/param.h>
#include <sys/sysctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

#include <mach/mach_init.h>
#include <mach/mach_host.h>
#include <mach/host_info.h>

#include "CPU.h"
#include "Command.h"
#include "ksysguardd.h"

/* CPU_STATE_* constants are defined in mach/machine.h via mach/host_info.h
 * These are available on Mac OS X 10.5+ including PowerPC systems
 */
#define CPU_STATES 4

/* Use unsigned long long for CPU tick counters to handle both 32-bit (PowerPC)
 * and 64-bit (Intel) architectures safely without overflow
 */
static unsigned long long cpu_time[CPU_STATES];
static unsigned long long cpu_old[CPU_STATES];
static int cpu_states[CPU_STATES];

void percentages(int cnt, int *out, unsigned long long *new, unsigned long long *old);

void initCpuInfo(struct SensorModul* sm)
{
    /* Total CPU load */
    registerMonitor("cpu/system/user", "integer", printCPUUser, printCPUUserInfo, sm);
    registerMonitor("cpu/system/nice", "integer", printCPUNice, printCPUNiceInfo, sm);
    registerMonitor("cpu/system/sys", "integer", printCPUSys, printCPUSysInfo, sm);
    registerMonitor("cpu/system/idle", "integer", printCPUIdle, printCPUIdleInfo, sm);

    /* Monitor names changed from kde3 => kde4. Remain compatible with legacy requests when possible. */
    registerLegacyMonitor("cpu/user", "integer", printCPUUser, printCPUUserInfo, sm);
    registerLegacyMonitor("cpu/nice", "integer", printCPUNice, printCPUNiceInfo, sm);
    registerLegacyMonitor("cpu/sys", "integer", printCPUSys, printCPUSysInfo, sm);
    registerLegacyMonitor("cpu/idle", "integer", printCPUIdle, printCPUIdleInfo, sm);

    updateCpuInfo();
}

void exitCpuInfo(void)
{
    removeMonitor("cpu/system/user");
    removeMonitor("cpu/system/nice");
    removeMonitor("cpu/system/sys");
    removeMonitor("cpu/system/idle");

    /* These were registered as legacy monitors */
    removeMonitor("cpu/user");
    removeMonitor("cpu/nice");
    removeMonitor("cpu/sys");
    removeMonitor("cpu/idle");
}

int updateCpuInfo(void)
{
    host_cpu_load_info_data_t cpuinfo;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;

    /* Get CPU load information using Mach host_statistics API
     * This API has been available since Mac OS X 10.0 and works on both
     * PowerPC and Intel architectures
     *
     * HOST_CPU_LOAD_INFO returns cumulative CPU ticks since boot in each state:
     * - CPU_STATE_USER: user mode (non-niced)
     * - CPU_STATE_NICE: user mode (niced)
     * - CPU_STATE_SYSTEM: kernel mode
     * - CPU_STATE_IDLE: idle
     */
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO,
                       (host_info_t)&cpuinfo, &count) == KERN_SUCCESS) {
        /* Store tick counts as unsigned long long to prevent overflow
         * cpu_ticks[] is defined as natural_t which is 32-bit on PowerPC
         * and 64-bit on modern Intel, but we normalize to 64-bit for safety
         */
        cpu_time[0] = (unsigned long long)cpuinfo.cpu_ticks[CPU_STATE_USER];
        cpu_time[1] = (unsigned long long)cpuinfo.cpu_ticks[CPU_STATE_NICE];
        cpu_time[2] = (unsigned long long)cpuinfo.cpu_ticks[CPU_STATE_SYSTEM];
        cpu_time[3] = (unsigned long long)cpuinfo.cpu_ticks[CPU_STATE_IDLE];

        percentages(CPU_STATES, cpu_states, cpu_time, cpu_old);
    }

    return 0;
}

void printCPUUser(const char* cmd)
{
    fprintf(CurrentClient, "%d\n", cpu_states[0]/10);
}

void printCPUUserInfo(const char* cmd)
{
    fprintf(CurrentClient, "CPU User Load\t0\t100\t%%\n");
}

void printCPUNice(const char* cmd)
{
    fprintf(CurrentClient, "%d\n", cpu_states[1]/10);
}

void printCPUNiceInfo(const char* cmd)
{
    fprintf(CurrentClient, "CPU Nice Load\t0\t100\t%%\n");
}

void printCPUSys(const char* cmd)
{
    fprintf(CurrentClient, "%d\n", cpu_states[2]/10);
}

void printCPUSysInfo(const char* cmd)
{
    fprintf(CurrentClient, "CPU System Load\t0\t100\t%%\n");
}

void printCPUIdle(const char* cmd)
{
    fprintf(CurrentClient, "%d\n", cpu_states[3]/10);
}

void printCPUIdleInfo(const char* cmd)
{
    fprintf(CurrentClient, "CPU Idle Load\t0\t100\t%%\n");
}

/* Percentages calculation - calculate percentages from differences
 * This function computes the percentage of time spent in each CPU state
 * since the last call, handling counter wraparound
 *
 * Based on the algorithm used in top(1) and other BSD system monitors
 */
void percentages(int cnt, int *out, unsigned long long *new, unsigned long long *old)
{
    int i;
    unsigned long long total_change, half_total;
    unsigned long long *dp = new;
    unsigned long long *op = old;

    /* Calculate total change across all CPU states
     * Handle counter wraparound (though unlikely on 64-bit)
     */
    total_change = 0;
    for (i = 0; i < cnt; i++) {
        if (*dp < *op) {
            /* Counter wrapped - calculate wrapped difference
             * This is rare but can happen on systems with very long uptimes
             * or on 32-bit PowerPC where counters are 32-bit natural_t
             */
            total_change += ((*dp - *op) + (unsigned long long)(-1));
        } else {
            total_change += (*dp - *op);
        }
        dp++;
        op++;
    }

    /* Avoid divide by zero on first call or if system was completely idle */
    if (total_change == 0)
        total_change = 1;

    /* Calculate percentages for each state
     * We multiply by 1000 to get tenths of percent (output/10 = percent)
     * Add half_total for rounding
     */
    half_total = total_change / 2;
    for (i = 0; i < cnt; i++) {
        if (new[i] < old[i]) {
            /* Handle wrapped counter */
            out[i] = (int)((((new[i] - old[i]) + (unsigned long long)(-1)) * 1000 + half_total) / total_change);
        } else {
            out[i] = (int)(((new[i] - old[i]) * 1000 + half_total) / total_change);
        }
        /* Save current value for next iteration */
        old[i] = new[i];
    }
}
