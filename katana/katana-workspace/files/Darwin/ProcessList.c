/*
    KSysGuard, the KDE System Guard

    Copyright (c) 1999-2000 Hans Petter Bieker<bieker@kde.org>
    Copyright (c) 1999 Chris Schlaeger <cs@kde.org>
    Copyright (c) 2025 macOS port - minimal stub

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

#include "ProcessList.h"
#include "Command.h"
#include "ksysguardd.h"

#include <stdio.h>

/*
 * Minimal stub implementation for macOS ProcessList
 * TODO: Implement full process monitoring using sysctl with CTL_KERN, KERN_PROC
 * or libproc APIs
 */

void initProcessList(struct SensorModul *sm) {
    /* Register a minimal process count monitor */
    registerMonitor("ps/count", "integer", printProcessCount, printProcessCountInfo, sm);
}

void exitProcessList(void) {
    removeMonitor("ps/count");
}

int updateProcessList(void) {
    /* Stub - would scan process list here */
    return 0;
}

void printProcessCount(const char* cmd) {
    /* Stub - return 0 for now */
    fprintf(CurrentClient, "0\n");
}

void printProcessCountInfo(const char* cmd) {
    fprintf(CurrentClient, "Number of Processes\t0\t0\t\n");
}

void printProcessList(const char* cmd) {
    /* Stub - would print full process list */
    fprintf(CurrentClient, "\n");
}

void printProcessListInfo(const char* cmd) {
    fprintf(CurrentClient, "Process List\n");
}

/* Stub functions for process control */
void killProcess(const char* cmd) {
    fprintf(CurrentClient, "0\n");
}

void setPriority(const char* cmd) {
    fprintf(CurrentClient, "0\n");
}
