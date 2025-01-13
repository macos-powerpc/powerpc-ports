# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4

# Copyright (c) 2015 The MacPorts Project
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
# Usage:
# PortGroup     kf5_frameworks 1.0
#
# This PortGroup provides the required macros to declare dependencies
# on KF5 Frameworks for ports that cannot easily use the main KF5 1.1
# PortGroup, for instance because they don't use CMake. Typically this
# will be ports providing software not provided through/for the KDE
# organisation, for example Qt applications that use just a select
# number of frameworks (like QupZilla can provide a KWallet backend).
#
# Usage:
#
# kf5.depends_frameworks :
# appends the ports corresponding to the KF5 Frameworks short names to
# depends_lib. This procedure also adds the build dependencies that
# KI18n imposes
# Caution though: some KF5 packages will let the KI18n dependency be added
# through cmake's public link interface handling, rather than declaring an
# explicit dependency themselves that is listed in the printed summary.
#
# kf5.depends_build_frameworks :
# the equivalent to kf5.depends_frameworks for declaring build dependencies.
#
# For more precise control one can use kf5::framework_dependency (note
# the :: instead of a "."!). For instance:
# depends_run-append    [kf5::framework_dependency kded]
# or by accessing the dependency variable directly:
# depends_run-append    ${kf5::kded_dep}


namespace eval kf5 {

    # internal and (hopefully) rarely used stuff is put in the KF5 namespace

    variable libs_ext

    variable pyversion       2.7
    variable pybranch        [join [lrange [split ${pyversion} .] 0 1] ""]

    if {${os.platform} eq "darwin"} {
        set libs_ext   dylib

        # this should probably become under control of a variant
        variable pythondep   port:python27
        variable pylibdir    ${frameworks_dir}/Python.framework/Versions/${pyversion}/lib/python${pyversion}
    } else {
        set libs_ext   so

        # for personal use: don't add a python dependency.
        variable pythondep   bin:python:python27
    }

    variable dbus_start_warning_printed no

    # wrapper meant to draw the user's attention to the fact that this port has notes
    # that are of interest before installation. Print the banner once only for every port
    # that has such notes.
    proc add_warning_note {msg} {
        global subport
        ui_warn_once "kf5::warning_note-${subport}" ">>> Please read the notes before installing (port notes ${subport} +your+variant+selection)! <<<\n"
        ui_info ${msg}
        notes-append ${msg}
    }

    # variables to facilitate setting up dependencies to KF5 frameworks that may (or not)
    # also exist as port:kf5-foo-devel .
    # This may be extended to provide path-style *runtime* dependencies on framework executables;
    # kf5.framework_runtime_dependency{name {executable 0}} and kf5.depends_run_frameworks
    # (which would have to add a library dependency if no executable dependency is defined).
    proc framework_dependency {name {library 0} {soversion 5}} {
        namespace upvar ::kf5 ${name}_dep kdep
        namespace upvar ::kf5 ${name}_lib lib
        if {${library} ne 0} {
            global os.platform build_arch
            if {${os.platform} eq "darwin"} {
                set lib_path        lib
                if {${soversion} ne ""} {
                    set lib_ext     5.dylib
                } else {
                    set lib_ext     dylib
                }
            } else {
                set lib_path        lib/${build_arch}-linux-gnu
                if {${soversion} ne ""} {
                    set lib_ext     so.5
                } else {
                    set lib_ext     so
                }
            }
            set lib                 ${lib_path}/${library}.${lib_ext}
            set kdep                 path:${lib}:kf5-${name}
            ui_debug "Dependency expression for KF5ramework ${name}: ${kdep}"
            # no return value in this branch
        } else {
            if {[info exists kdep]} {
                platform darwin {
                    if {![catch {set nativeQSP [active_variants "${kdep}" nativeQSP]}]} {
                        global subport
                        if {${nativeQSP}} {
                            # dependency is built for native QSP locations but the dependent port wants ALT (XDG) locations
                            if {([variant_isset qspXDG] || ![variant_isset nativeQSP])} {
                                kf5::add_warning_note "Warning: ${subport} potential mismatch with kf5-${name}+nativeQSP"
                            }
                        } elseif {[variant_isset nativeQSP]} {
                            # dependency is built for ALT (XDG) QSP locations but the dependent port wants to use native locations
                            kf5::add_warning_note "Warning: ${subport}+nativeQSP potential mismatch with kf5-${name} (-nativeQSP)"
                        }
                    }
                    if {[lsearch {"baloo" "kactivities" "kdbusaddons" "kded" "kdelibs4support-devel" "kglobalaccel" "kio"
                                    "kservice" "kwallet" "kwalletmanager" "plasma-framework"} ${name}] ne "-1"} {
                        if {!${kf5::dbus_start_warning_printed}} {
                            if {[catch {exec ps -ax | fgrep dbus-daemon} result]} {
                                ui_debug "dbus-daemon isn't running: ${result}"
                                notes-append "
                                    Don't forget that dbus needs to be started as the local\
                                    user (not with sudo) before any KDE programs will launch.
                                    To start it run the following command:
                                     launchctl load -w /Library/LaunchAgents/org.freedesktop.dbus-session.plist
                                    "
                            }
                            set kf5::dbus_start_warning_printed yes
                        }
                    }
                }
                return ${kdep}
            } else {
                set allknown [string map {"::kf5::" "" "_dep" ""} [info vars "::kf5::*_dep"]]
                ui_error "No KF5 framework is known corresponding to \"${name}\""
                ui_msg "Known framework ports: ${allknown}"
                return -code error "Unknown KF5 framework ${name}"
            }
        }
    }

    proc has_translations {} {
        global prefix
        ui_debug "Adding gettext and ${kf5::pythondep} (build) dependencies because of KI18n"
        depends_lib-append \
                        port:gettext
        depends_build-append \
                        ${kf5::pythondep}
        ifplatform other {
            depends_build-append \
                    port:gettext-dev
        }
        configure.args-append \
                        -DPYTHON_EXECUTABLE=${prefix}/bin/python${kf5::pyversion}
    }
}

# public variables:
if {${os.platform} eq "linux"} {
    set kf5.libs_dir    ${prefix}/lib/${build_arch}-linux-gnu
} else {
    set kf5.libs_dir    ${prefix}/lib
}

proc kf5.depends_frameworks {first args} {
    # join ${first} and (the optional) ${args}
    set args [linsert $args[set list {}] 0 ${first}]
    foreach f ${args} {
        depends_lib-append \
                        [kf5::framework_dependency ${f}]
    }
    if {[lsearch -exact ${args} "ki18n"] ne "-1"} {
        kf5::has_translations
    }
    if {[lsearch -exact ${args} "kdoctools"] ne "-1"
        && [lsearch [option depends_lib] "docbook-x"] eq -1
    } {
        depends_lib-append \
                        port:docbook-xml port:docbook-xsl-nons
    }
}

proc kf5.depends_build_frameworks {first args} {
    # join ${first} and (the optional) ${args}
    set args [linsert $args[set list {}] 0 ${first}]
    foreach f ${args} {
        depends_build-append \
                        [kf5::framework_dependency ${f}]
    }
    if {[lsearch -exact ${args} "ki18n"] ne "-1"} {
        kf5::has_translations
    }
    if {[lsearch -exact ${args} "kdoctools"] ne "-1"
        && [lsearch [option depends_build] "docbook-x"] eq -1
    } {
        depends_build-append \
                        port:docbook-xml port:docbook-xsl-nons
    }
}

proc kf5.depends_run_frameworks {first args} {
    # join ${first} and (the optional) ${args}
    set args [linsert $args[set list {}] 0 ${first}]
    foreach f ${args} {
        depends_run-append \
                        [kf5::framework_dependency ${f}]
    }
}

kf5::framework_dependency    attica libKF5Attica
kf5::framework_dependency    karchive libKF5Archive
kf5::framework_dependency    kcoreaddons libKF5CoreAddons
kf5::framework_dependency    kauth libKF5Auth
set kf5::breeze-icons_dep    path:share/icons/breeze/index.theme:kf5-breeze-icons
kf5::framework_dependency    kconfig libKF5ConfigCore
kf5::framework_dependency    kcodecs libKF5Codecs
kf5::framework_dependency    ki18n libKF5I18n
# kf5-kdoctools does install a static library but meinproc5 is what's used more visibly
set kf5::kdoctools_dep       path:bin/meinproc5:kf5-kdoctools
kf5::framework_dependency    kguiaddons libKF5GuiAddons
kf5::framework_dependency    ksyntaxhighlighting libKF5SyntaxHighlighting
kf5::framework_dependency    kwidgetsaddons libKF5WidgetsAddons
kf5::framework_dependency    kconfigwidgets libKF5ConfigWidgets
kf5::framework_dependency    kitemviews libKF5ItemViews
kf5::framework_dependency    kiconthemes libKF5IconThemes
kf5::framework_dependency    kwindowsystem libKF5WindowSystem
kf5::framework_dependency    kcrash libKF5Crash
set kf5::kgenapidox_dep      path:bin/kgenapidox:kf5-kgenapidox
set kf5::kapidox_dep         path:bin/kapidox_generate:kf5-kapidox
kf5::framework_dependency    kdbusaddons libKF5DBusAddons
kf5::framework_dependency    kdnssd libKF5DNSSD
kf5::framework_dependency    kidletime libKF5IdleTime
set kf5::kimageformats_dep   port:kf5-kimageformats
kf5::framework_dependency    kitemmodels libKF5ItemModels
kf5::framework_dependency    kplotting libKF5Plotting
set kf5::oxygen-icons_dep    path:share/icons/oxygen/index.theme:kf5-oxygen-icons5
kf5::framework_dependency    solid libKF5Solid
kf5::framework_dependency    sonnet libKF5SonnetCore
kf5::framework_dependency    threadweaver libKF5ThreadWeaver
kf5::framework_dependency    kcompletion libKF5Completion
kf5::framework_dependency    kfilemetadata libKF5FileMetaData
kf5::framework_dependency    kjobwidgets libKF5JobWidgets
kf5::framework_dependency    knotifications libKF5Notifications
kf5::framework_dependency    kunitconversion libKF5UnitConversion
kf5::framework_dependency    kpackage libKF5Package
kf5::framework_dependency    kservice libKF5Service
kf5::framework_dependency    ktextwidgets libKF5TextWidgets
kf5::framework_dependency    kglobalaccel libKF5GlobalAccel
kf5::framework_dependency    kxmlgui libKF5XmlGui
kf5::framework_dependency    kbookmarks libKF5Bookmarks
kf5::framework_dependency    kwallet libKF5Wallet
kf5::framework_dependency    kio libKF5KIOCore
kf5::framework_dependency    baloo libKF5Baloo
kf5::framework_dependency    kdeclarative libKF5Declarative
kf5::framework_dependency    kcmutils libKF5KCMUtils
kf5::framework_dependency    kemoticons libKF5Emoticons
# this is really a framework... (but is being phased out)
kf5::framework_dependency    gpgmepp libKF5Gpgmepp
# kf5-kinit does install a library but it may not be the best choice as a dependency:
# hard to tell at this moment how many dependents actually use that rather than
# depending on one of the framework's executables.
kf5::framework_dependency    kinit libkdeinit5_klauncher ""
kf5::framework_dependency    kded libkdeinit5_kded5 ""
kf5::framework_dependency    kparts libKF5Parts
kf5::framework_dependency    kdewebkit libKF5WebKit
set kf5::kdesignerplugin_dep path:bin/kgendesignerplugin:kf5-kdesignerplugin
kf5::framework_dependency    kpty libKF5Pty
kf5::framework_dependency    kdelibs4support libKF5KDELibs4Support
kf5::framework_dependency    frameworkintegration libKF5Style
kf5::framework_dependency    kpeople libKF5People
kf5::framework_dependency    ktexteditor libKF5TextEditor
kf5::framework_dependency    kxmlrpcclient libKF5XmlRpcClient
kf5::framework_dependency    kactivities libKF5Activities
kf5::framework_dependency    kdesu libKF5Su
kf5::framework_dependency    knewstuff libKF5NewStuff
kf5::framework_dependency    knotifyconfig libKF5NotifyConfig
kf5::framework_dependency    plasma-framework libKF5Plasma
kf5::framework_dependency    kjs libKF5JS
kf5::framework_dependency    khtml libKF5KHtml
kf5::framework_dependency    kross libKF5KrossCore
kf5::framework_dependency    krunner libKF5Runner
kf5::framework_dependency    kwayland libKF5WaylandClient
kf5::framework_dependency    kuserfeedback libKUserFeedbackCore
kf5::framework_dependency    kactivities-stats libKF5ActivitiesStats
kf5::framework_dependency    purpose libKF5Purpose
kf5::framework_dependency    kjsembed libKF5JsEmbed
kf5::framework_dependency    bluezqt libKF5BluezQt
kf5::framework_dependency    networkmanagerqt libKF5NetworkManagerQt

# QML frameworks, should be used as runtime deps:
set kf5::kirigami_dep        path:${qt_qml_dir}/org/kde/kirigami/libkirigamiplugin.${kf5::libs_ext}:kf5-kirigami
set kf5::kirigami2_dep       path:${qt_qml_dir}/org/kde/kirigami.2/libkirigamiplugin.${kf5::libs_ext}:kf5-kirigami2
set kf5::qqc2desktopstyle_dep \
                            path:${qt_qml_dir}/org/kde/qqc2desktopstyle/private/libqqc2desktopstyleplugin.${kf5::libs_ext}:kf5-qqc2-desktop-style

# not a framework; use the procedure to define the path-style dependency
kf5::framework_dependency    cli-tools libkdeinit5_kcmshell5 ""

set kf5::osx-integration_dep path:${qt_cmake_module_dir}/KF5OSXIntegration/KF5OSXIntegrationConfig.cmake:kf5-osx-integration-devel

# kate: backspace-indents true; indent-pasted-text true; indent-width 4; keep-extra-spaces true; remove-trailing-spaces modified; replace-tabs true; replace-tabs-save true; syntax MacPorts/Portfile; tab-indents true; tab-width 4;
