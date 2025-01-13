# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Copyright (c) 2014 The MacPorts Project
# Copyright (c) 2015, 2016 R.J.V. Bertin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
# This portgroup defines standard settings when using Qt5.
#
# Usage:
# PortGroup     qt5 1.0
#
# or
#
# set qt5.prefer_kde    1
# PortGroup             qt5 1.0

### testing testing testing ###
PortGroup           qt5-stock 1.0
return
###############################

###########################################################################################
# Check what Qt5 port and PortGroup we should be using, based on indicated port preference,
# what is already installed and OS version.
# Given that ports exist for multiple Qt5 versions it is easier to distinguish port:qt5 and
# port:qt5-kde from differences in install layout than from active installed portnames.

# first, check if port:qt5-kde or a port:qt5-kde-devel is installed, or if we're on Mac OS X 10.6
# NB: the qt5-kde-devel ports may never exist officially in MacPorts but is used locally by KF5 port maintainers!
# NB2 : ${prefix} isn't set by portindex but registry_active can be used!!
if {[file exists ${prefix}/include/qt5/QtCore/QtCore] || ${os.major} == 10
        || ([catch {registry_active "qt5-kde"}] == 0 || [catch {registry_active "qt5-kde-devel"}] == 0) } {
    set qt5PGname "qt5-kde"
} elseif {[file exists ${prefix}/libexec/qt5/plugins/platforms/libqcocoa.dylib]
        && [file type ${prefix}/libexec/qt5/plugins] eq "directory"
        && ![variant_isset qt5kde]} {
    # qt5-qtbase is installed: Qt5 has been installed through a standard port:qt5 port
    # (checking if "plugins" is a directory is probably redundant)
    # We're already in the correct PortGroup
    set qt5PGname "qt5"
} elseif {[info exists qt5.prefer_kde] || [variant_isset qt5kde]} {
    # The calling port has indicated a preference and no Qt5 port is installed already
    # transfer control to qt5-kde-1.0.tcl
    ui_debug "port:qt5-kde has been requested explicitly"
    set qt5PGname "qt5-kde"
} else {
    ui_debug "Qt5 will be provided by port:qt5 (default)"
    set qt5PGname "qt5"
}

if {[tbool just_want_qt5_variables]} {
    ui_debug "just_want_qt5_variables is set, we need to use the Qt5 PG"
    set qt5PGname "qt5"
} elseif {[tbool building_qt5] && ![tbool qt5.prefer_kde]} {
    ui_debug "building port:qt5-qtbase, we need to use the Qt5 PG"
    set qt5PGname "qt5"
} elseif {[tbool qt5.prefer_default]} {
    ui_debug "qt5.prefer_default is set, we will use the Qt5 PG"
    set qt5PGname "qt5"
}

# do the actual PortGroup import - note that we do NOT return immediately afterwards, here.
switch -exact ${qt5PGname} {
    qt5-kde {
        # Qt5 has been installed through port:qt5-kde or port:qt5-kde-devel or we're on 10.6
        # transfer control to qt5-kde-1.0.tcl
        ui_debug "Qt5 is provided by port:qt5-kde"
        set qt5.using_kde   yes
        PortGroup           ${qt5PGname} 1.0
    }
    default {
        # default situation: we're already in the correct PortGroup, unless:
        if {[variant_isset qt5kde] || ([info exists qt5.prefer_kde] && [info exists building_qt5])} {
            if {[variant_isset qt5kde]} {
                ui_error "You cannot install ports with the +qt5kde variant when port:qt5 or one of its subports installed!"
            } else {
                # user tries to install say qt5-kde-qtwebkit against qt5-qtbase etc.
                ui_error "You cannot install a Qt5-KDE port with port:qt5 or one of its subports installed!"
            }
            # print the error but only raise it when attempting to fetch or configure the port.
            pre-fetch {
                return -code error "Deactivate the conflicting port:qt5 port(s) first!"
            }
            pre-configure {
                return -code error "Deactivate the conflicting port:qt5 port(s) first!"
            }
        }
        set qt5.using_kde   no
        PortGroup           ${qt5PGname} 1.0
    }
}

if {[info exists qt5.prefer_kde]} {
    # this is a port that prefers port:qt5-kde and thus expects most of Qt5 to be installed
    # through that single port rather than enumerate all components it depends on.
    depends_lib-append  port:qt5
    # the port may also use a variable that is still provided by qt5-kde-1.0.tcl;
    # set it to an empty value so that it can be referenced without side-effects.
    global qt_cmake_defines
    set qt_cmake_defines ""
}
###########################################################################################

proc qt_branch {} {
    global version
    return [join [lrange [split ${version} .] 0 1] .]
}

# Ports that want to provide a universal variant need to use the muniversal PortGroup explicitly.
universal_variant no

global available_qt_versions
set available_qt_versions {
    qt5
    qt55
    qt56
    qt5-kde
    qt56-kde
}

# kate: backspace-indents true; indent-pasted-text true; indent-width 4; keep-extra-spaces true; remove-trailing-spaces modified; replace-tabs true; replace-tabs-save true; syntax Tcl/Tk; tab-indents true; tab-width 4;
