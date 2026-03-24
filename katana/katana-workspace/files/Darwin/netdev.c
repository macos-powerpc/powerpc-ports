/*
    KSysGuard, the KDE System Guard

    Copyright (c) 2001 Tobias Koenig <tokoe@kde.org>
    Copyright (c) 2025 macOS port - minimal stub

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

*/

#include "netdev.h"
#include "Command.h"
#include "ksysguardd.h"

#include <stdio.h>

/*
 * Minimal stub implementation for macOS network devices
 * TODO: Implement using getifaddrs() and sysctl or IOKit
 */

void initNetDev(struct SensorModul* sm) {
    /* Stub - would register network interface monitors */
}

void exitNetDev(void) {
    /* Stub */
}

int updateNetDev(void) {
    /* Stub - would update network statistics */
    return 0;
}
