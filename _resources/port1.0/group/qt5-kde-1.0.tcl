# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# Copyright (c) 2014 The MacPorts Project
# Copyright (c) 2013-11-26 michaelld@macports.org
# Copyright (c) 2015-2018 R.J.V. Bertin
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
# set qt5.prefer_kde 1
# PortGroup     qt5 1.0
# or
# PortGroup     qt5-kde 1.0
#
# Define qt5.depends_qtwebengine before including the portgroup to add
# a dependency on qt5-kde-qtwebengine .

# shameless copy from the qt5-stock 1.0 PortGroup
# Qt has what is calls reference configurations, which are said to be thoroughly tested
# Qt also has configurations which are occasionally tested
# see http://doc.qt.io/qt-5/supported-platforms.html#reference-configurations
# global qt5_min_tested_version
# global qt5_max_tested_version
# global qt5_min_reference_version
# global qt5_max_reference_version
# set qt5_min_tested_version     12
# set qt5_max_tested_version     15
# set qt5_min_reference_version  12
# set qt5_max_reference_version  15

# define all available port:qt5* versions
global available_qt5_versions
set available_qt5_versions {
    qt5  {qt5-kde  5.9}
    qt58 {qt58-kde 5.8}
    qt56 {qt56-kde 5.6}
    qt54 {qt54-kde 5.4}
    qt53 {qt53-kde 5.3}
}

if {[tbool just_want_qt5_version_info]} {
    PortGroup           qt5 1.0
    # can't return here anymore since "base" now blocks multiple PG inclusion
    ui_warn "just_want_qt5_version_info is true, but obsolete and ignored nowadays"
    #return
}

# Check what Qt5 installation flavour already exists, or if not if the port calling us
# indicated a preference. If not, use the default/mainstream port:qt5 .
# Also use qt5-kde if we're on 10.6 because qt5-kde provides a fallback to Qt 5.3.2 on that OS version

# first, check if port:qt5-kde or a port:qt5-kde-devel is installed, or if we're on Mac OS X 10.6
# NB: the qt5-kde-devel ports may never exist officially in MacPorts but is used locally by KF5 port maintainers!
# NB2 : ${prefix} isn't set by portindex but registry_active can be used!!
# NB3 : this is a simpler variant of the equivalent block in qt5-1.0.tcl and qt5-stock-1.0.tcl.tcl;
# it can be because we have strict(er) control over who includes this, and the tests are redundant
# if we come here via one of the aforementioned PortGroup files.
if {[file exists ${prefix}/include/qt5/QtCore/QtCore] || ${os.major} == 10
        || ([catch {registry_active "qt5-kde"}] == 0 || [catch {registry_active "qt5-kde-devel"}] == 0) } {
    # Qt5 has been installed through port:qt5-kde or port:qt5-kde-devel
    ui_debug "Qt5 is provided by port:qt5-kde"
    # we're in the right PortGroup, otherwise we'd need to
    # PortGroup           qt5-kde 1.0
    set qt5.using_kde   yes
} elseif {[file exists ${prefix}/libexec/qt5/plugins/platforms/libqcocoa.dylib]
        && [file type ${prefix}/libexec/qt5/plugins] eq "directory"} {
    # qt5-qtbase is installed: Qt5 has been installed through a standard port:qt5 port
    # (checking if "plugins" is a directory is probably redundant)
    ui_debug "Qt5 is provided by port:qt5"
    PortGroup           qt5 1.0
    if {[variant_isset qt5kde] || ([info exists qt5.prefer_kde] && [info exists building_qt5])} {
        if {[variant_isset qt5kde]} {
            ui_error "You cannot install ports with the +qt5kde variant when port:qt5 or one of its subports active!"
        } else {
            # user tries to install say qt5-kde-qtwebkit against qt5-qtbase etc.
            ui_error "You cannot install a Qt5-KDE port with port:qt5 or one of its subports active!"
        }
        # print the error but only raise it when attempting to fetch or configure the port.
        pre-fetch {
            return -code error "Deactivate the conflicting port:qt5 port(s) first!"
        }
        pre-configure {
            return -code error "Deactivate the conflicting port:qt5 port(s) first!"
        }
    }
    # we're done
    return
} elseif {[info exists qt5.prefer_kde] || [variant_isset qt5kde]} {
    # The calling port has indicated a preference and no Qt5 port is installed already
    ui_debug "Qt5 will be provided by port:qt5-kde, by request"
    # we're in the right PortGroup, otherwise we'd need to
    # PortGroup           qt5-kde 1.0
    set qt5.using_kde   yes
} else {
    # default fall-back to mainstream port:qt5
    ui_debug "Qt5 will be provided by port:qt5 (default)"
    PortGroup           qt5 1.0
    # we're done
    return
}

######### checks that should never trigger #########
if {[file exists ${prefix}/libexec/qt5/plugins/platforms/libqcocoa.dylib]
    && [file type ${prefix}/libexec/qt5/plugins] eq "directory"} {
    # Qt5 has been installed through port:qt5, which leads to certain incompatibilities
    # which do not need to be declared otherwise. The header Qt5 PortGroup has similar
    # checks and provisions, but since ports can also include us directly we have to
    # repeat them here.
    conflicts-append qt5-qtbase
    if {[info exists building_qt5]} {
        PortGroup conflicts_build 1.0
        conflicts_build-append qt5-qtbase
        ui_info "Qt5 has been installed through port:qt5 or its subports; you cannot build ${subport}"
        pre-fetch {
            return -code error "Deactivate the conflicting port:qt5 (subports) first!"
        }
        pre-configure {
            return -code error "Deactivate the conflicting port:qt5 (subports) first!"
        }
    } else {
        ui_info "Qt5 has been installed through port:qt5 or its subports; you can build but not install ${subport}"
    }
}
if {[info exists qt5.using_kde] && !${qt5.using_kde}} {
    # checks if the other Qt5 PortGroup has already been included.
    # NB: this works only when that happened through the qt5-1.0.tcl!
    ui_error "qt5-kde-1.0.tcl is being imported after qt5-stock-1.0.tcl.tcl"
    return -code error "importing 2 incompatible Qt5 PortGroups"
}
####################################################

### These should be set (re)set on each invocation:
# standard Qt5 name. This should be just "qt5" (or qt53 for instance when more
# specific version info must be included).
global qt_name
if {[info exists qt5::rootname]} {
    # a kludgy way to declare a different prefix for the Qt tooldir and bindir as well as the shared dirs.
    # Deliberately user unfriendly.
    set qt_name         ${qt5::rootname}
} else {
    set qt_name         qt5
}

# global definitions with explanation; set the actual values below for cleanness.
# standard install directory
    global qt_dir
# idem, relative to ${prefix}
    global qt_dir_rel
# archdata: equal to qt_dir
    global qt_archdata_dir
# standard Qt documents directory
    global qt_docs_dir
# standard Qt plugins directory
    global qt_plugins_dir
# standard Qt mkspecs directory
    global qt_mkspecs_dir
# standard Qt imports directory
    global qt_imports_dir
# standard Qt qml directory
    global qt_qml_dir
# standard Qt includes directory, under ${prefix}/includes where they would be expected
    global qt_includes_dir
# standard Qt libraries directory
    global qt_libs_dir
# standard Qt libraries directory: OS X frameworks
    global qt_frameworks_dir
# idem, relative to ${prefix}
    global qt_frameworks_dir_rel
# standard Qt non-.app executables directory
    global qt_bins_dir
# standard Qt data directory
    global qt_data_dir
# standard Qt translations directory
    global qt_translations_dir
# standard Qt sysconf directory
    global qt_sysconf_dir
# standard Qt .app executables directory, if created
    global qt_apps_dir
# standard Qt examples directory
    global qt_examples_dir
# standard Qt demos directory
    global qt_demos_dir
# standard Qt tests directory
    global qt_tests_dir
# standard CMake module directory for Qt-related files
# no idea why you'd need to protect this one against multiple defines...!
if {![info exists qt_cmake_module_dir]} {
    global qt_cmake_module_dir
}
# standard qmake command location
    global qt_qmake_cmd
# standard moc command location
    global qt_moc_cmd
# standard uic command location
    global qt_uic_cmd
# standard lrelease command location
    global qt_lrelease_cmd
    global qt_lupdate_cmd
# location of a simple, dedicated install registry:
    global qt_install_registry
# standard PKGCONFIG path
    global qt_pkg_config_dir
# data used by qmake
    global qt_host_data_dir

global qt5_is_concurrent
set qt5_is_concurrent       1

# NB: these have all already been set by the mainstream Qt5 PG (qt5-stock-1.0.tcl.tcl)
# that port family's layout is different so we have to reset everything here.
# NB: That means we have to keep the variable list in sync!
set qt_dir                  ${prefix}/libexec/${qt_name}
set qt_dir_rel              libexec/${qt_name}
set qt_includes_dir         ${prefix}/include/${qt_name}
set qt_libs_dir             ${qt_dir}/lib
set qt_frameworks_dir       ${qt_dir}/Library/Frameworks
set qt_frameworks_dir_rel   ${qt_dir_rel}/Library/Frameworks
set qt_bins_dir             ${qt_dir}/bin
set qt_cmake_module_dir     ${prefix}/lib/cmake
set qt_archdata_dir         ${qt_dir}
set qt_sysconf_dir          ${prefix}/etc/${qt_name}
set qt_data_dir             ${prefix}/share/${qt_name}
set qt_plugins_dir          ${prefix}/share/${qt_name}/plugins
set qt_mkspecs_dir          ${prefix}/share/${qt_name}/mkspecs
set qt_imports_dir          ${prefix}/share/${qt_name}/imports
set qt_qml_dir              ${prefix}/share/${qt_name}/qml
set qt_translations_dir     ${prefix}/share/${qt_name}/translations
set qt_tests_dir            ${prefix}/share/${qt_name}/tests
set qt_docs_dir             ${prefix}/share/doc/${qt_name}

set qt_qmake_cmd            ${qt_dir}/bin/qmake
set qt_moc_cmd              ${qt_dir}/bin/moc
set qt_uic_cmd              ${qt_dir}/bin/uic
set qt_lrelease_cmd         ${qt_dir}/bin/lrelease
set qt_lupdate_cmd          ${qt_dir}/bin/lupdate

if {${os.platform} eq "darwin"} {
    set qt_apps_dir         ${applications_dir}/Qt5
} else {
    set qt_apps_dir         ${qt_bins_dir}
}
set qt_examples_dir         ${qt_apps_dir}/examples
set qt_demos_dir            ${qt_apps_dir}/demos

set qt_pkg_config_dir       ${prefix}/lib/pkgconfig
set qt_host_data_dir        ${prefix}/share/${qt_name}

### The remaining part can be skipped even if we just included the qt5-mac PG a 2nd time
namespace eval qt5 {
    if {[info exists dont_include_twice] && [info exists currentportgroupdir]} {
        ui_debug "not including qt5-kde-1.0.tcl again"
        return
    }
    # our directory:
    variable currentportgroupdir [file dirname [dict get [info frame 0] file]]
}

options qt5.min_version
default qt5.min_version 5.0

# Ports that want to provide a universal variant need to use the muniversal PortGroup explicitly.
universal_variant no

if {![variant_exists qt5kde]} {
    # define a variant that will be set default when port:qt5-kde or port:qt5-kde-devel is
    # installed. This means that a user doing a new install (or upgrade) of a port depending
    # on Qt5 and with port:qt5-kde installed will request a variant the build bots should not
    # consider a default variant. This meant to protect against pulling in a binary build against
    # the wrong Qt5 port, which was relevant in the time of port:qt5-mac, and hopefully no
    # longer now that port:qt5 installs to the same place as we do (but as an all-inclusive prefix).
    variant qt5kde description {default variant set for port:qt5-kde* and ports that depend on them} {}
}
# it should no longer be necessary to set qt5kde but we will continue to do so for now.
if {[variant_isset qt5kde]} {
    ui_debug "+qt5kde is set for port:${subport}"
} else {
    ui_debug "+qt5kde is not yet set but will be for port:${subport}"
}
default_variants        +qt5kde

# ui_debug "qt_dir=${qt_dir}"
# ui_debug "qt_dir_rel=${qt_dir_rel}"
# ui_debug "qt_includes_dir=${qt_includes_dir}"
# ui_debug "qt_libs_dir=${qt_libs_dir}"
# ui_debug "qt_frameworks_dir=${qt_frameworks_dir}"
# ui_debug "qt_frameworks_dir_rel=${qt_frameworks_dir_rel}"
# ui_debug "qt_bins_dir=${qt_bins_dir}"
# ui_debug "qt_cmake_module_dir=${qt_cmake_module_dir}"
# ui_debug "qt_archdata_dir=${qt_archdata_dir}"
# ui_debug "qt_sysconf_dir=${qt_sysconf_dir}"
# ui_debug "qt_data_dir=${qt_data_dir}"
# ui_debug "qt_plugins_dir=${qt_plugins_dir}"
# ui_debug "qt_mkspecs_dir=${qt_mkspecs_dir}"
# ui_debug "qt_imports_dir=${qt_imports_dir}"
# ui_debug "qt_qml_dir=${qt_qml_dir}"
# ui_debug "qt_translations_dir=${qt_translations_dir}"
# ui_debug "qt_tests_dir=${qt_tests_dir}"
# ui_debug "qt_docs_dir=${qt_docs_dir}"
# ui_debug "qt_qmake_cmd=${qt_qmake_cmd}"
# ui_debug "qt_moc_cmd=${qt_moc_cmd}"
# ui_debug "qt_uic_cmd=${qt_uic_cmd}"
# ui_debug "qt_lrelease_cmd=${qt_lrelease_cmd}"
# ui_debug "qt_lupdate_cmd=${qt_lupdate_cmd}"
# ui_debug "qt_apps_dir=${qt_apps_dir}"
# ui_debug "qt_examples_dir=${qt_examples_dir}"
# ui_debug "qt_demos_dir=${qt_demos_dir}"
# ui_debug "qt_pkg_config_dir=${qt_pkg_config_dir}"
# ui_debug "qt_host_data_dir=${qt_host_data_dir}"

set qt_install_registry     ${qt_dir}/registry

if {${os.platform} eq "darwin"} {
    compiler.whitelist      clang
#     compiler.whitelist      clang macports-clang-3.7 macports-clang-3.6 macports-clang-3.5 macports-clang-3.4
}
compiler.blacklist-append   macports-llvm-gcc-4.2 llvm-gcc-4.2
compiler.blacklist-append   gcc-4.2 apple-gcc-4.2 gcc-4.0
compiler.blacklist-append   {clang < 500}
platform darwin {
    if {${os.major} >= 13 && [info exists building_qt5]} {
        compiler.blacklist-append *gcc*
    }
}

# # starting with the one-but-newest macports-clang in the whitelist, check it it is
# # installed and blacklist the other values so that the automatic selection mechanism
# # will select the installed whitelisted version.
# foreach v {3.6 3.5 3.4} {
#     if {[file exists ${prefix}/libexec/llvm-${v}/bin/clang]} {
#         foreach o {3.7 3.6 3.5 3.4} {
#             if {${o} ne ${v}} {
#                 compiler.blacklist-append   macports-clang-${o}
#             }
#         }
#     }
# }

if {[file exists ${qt5::currentportgroupdir}/macports_clang_selection-1.0.tcl]} {
    PortGroup               macports_clang_selection 1.0
    if {${os.platform} eq "darwin"} {
        if {${os.platform} > 10} {
            whitelist_macports_clang_versions   {3.7 3.6 3.5 3.4}
        } else {
            whitelist_macports_clang_versions   {3.5 3.4}
        }
        blacklist_macports_clang_versions       {< 3.4}
    }
}

# set Qt understood arch types, based on user preference
options qt_arch_types
default qt_arch_types {[string map {i386 x86} [get_canonical_archs]]}

# global qt_qmake_spec
options qt_qmake_spec
global qt_qmake_spec_32
global qt_qmake_spec_64

if {${os.platform} eq "darwin"} {
    if {[string match macports-gcc* ${configure.compiler}]} {
        # probably no need to test for *gcc* as the system `gcc`/`g++` commands that are
        # actually GNU GCC most certainly are too old to build modern Qt code.
        set qt_qmake_spec_32        macx-g++
        set qt_qmake_spec_64        macx-g++
    } else {
        set qt_qmake_spec_32        macx-clang
        set qt_qmake_spec_64        macx-clang
    }
} elseif {${os.platform} eq "linux"} {
    if {[string match *clang* ${configure.compiler}]} {
        set qt_qmake_spec_32    linux-clang
        set qt_qmake_spec_64    linux-clang
        pre-configure {
            # this has probably not been taken care of:
            if {![string match "*-std=c++*" ${configure.cxxflags}]} {
                if {${compiler.cxx_standard} > 2011} {
                    configure.cxxflags-append \
                                -std=c++[string range ${compiler.cxx_standard} end-1 end]
                } else {
                    configure.cxxflags-append \
                                -std=c++11
                }
            }
        }
    } else {
        set qt_qmake_spec_32    linux-g++
        set qt_qmake_spec_64    linux-g++-64
    }
} else {
    if {[string match *clang* ${configure.compiler}]} {
        set qt_qmake_spec_32    "${os.platform}-clang"
        pre-configure {
            # this has probably not been taken care of:
                if {${compiler.cxx_standard} > 2011} {
                    configure.cxxflags-append \
                                -std=c++[string range ${compiler.cxx_standard} end-1 end]
                } else {
                    configure.cxxflags-append \
                                -std=c++11
                }
        }
    } else {
        set qt_qmake_spec_32    "${os.platform}-g++"
#         compiler.blacklist-append \
#                                 clang
    }
    set qt_qmake_spec_64        ${qt_qmake_spec_32}
}

proc qt5::get_default_spec {} {
    global build_arch qt_qmake_spec_32 qt_qmake_spec_64
    if { ![option universal_variant] || ![variant_isset universal] } {
        if { ${build_arch} eq "i386" } {
            return ${qt_qmake_spec_32}
        } else {
            return ${qt_qmake_spec_64}
        }
    } else {
        return ""
    }
}

default qt_qmake_spec           {[qt5::get_default_spec]}

# if {![info exists qt_qmake_spec]} {
#     ui_warn "You're including a qt5 PortGroup from inside a variant declaration"
#     ui_warn "This is currently impossible. Instead, use"
#     ui_warn "if \{\[variant_isset foo\]\} \{"
#     ui_warn "    PortGroup qt5 1.0 # or PortGroup qt5-kde"
#     ui_warn "    ..."
#     ui_warn "\}"
#     ui_warn "Port: ${subport}"
# }

# standard cmake info for Qt5
global qt_cmake_defines
set qt_cmake_defines    \
    "-DQT_QT_INCLUDE_DIR=${qt_includes_dir} \
     -DQT_ZLIB_LIBRARY=${prefix}/lib/libz.dylib \
     -DQT_PNG_LIBRARY=${prefix}/lib/libpng.dylib"
if {[option qt_qmake_spec] ne ""} {
    set qt_cmake_defines \
        "${qt_cmake_defines} -DQT_QMAKESPEC=[option qt_qmake_spec]"
}

if {${os.platform} eq "darwin"} {
    # extensions on shared libraries
    set qt_libs_ext     dylib
    # extensions on plugins created by Qt's build system
    set qt_plugins_ext  dylib
} else {
    set qt_libs_ext     so
    set qt_plugins_ext  so
}

# allow for depending on either qt5[-mac] or qt5[-mac]-devel or qt5[-mac]*-kde, simultaneously

proc qt5.active_version {} {
    global prefix
    namespace upvar ::qt5 active_version av
    if {[info exists av]} {
        return ${av}
    }
    if {[info exists building_qt5]} {
        set av ${version}
        return ${av}
    } elseif {[file exists ${prefix}/bin/pkg-config]} {
        if {![catch {set av [exec ${prefix}/bin/pkg-config --modversion Qt5Core]} err]} {
            return ${av}
        }
        # else: Qt5 isn't installed yet
    }
    return 0.0.0
}

proc qt5.active_branch {{install_branch 5}} {
    global prefix
    namespace upvar ::qt5 active_branch ab
    if {[info exists ab]} {
        return ${ab}
    }
    set ab [join [lrange [split [qt5.active_version] .] 0 1] .]
    if {${ab} == 0.0} {
        set ab ${install_branch}
    }
    return ${ab}
}

## NB
## Remember to update the component2pathspec table when promoting
## a stubport to a (sub)port!
set qt5.kde_stubports \
            {qtbase qtdeclarative qtserialbus qtserialport qtsensors \
            qtquick1 qtwebchannel qtimageformats qtsvg qtmacextras qtx11extras \
            qtlocation qtxmlpatterns qtcanvas3d qtgraphicaleffects qtmultimedia \
            qtscript qt3d qtconnectivity qttools qtquickcontrols qtquickcontrols2 \
            qtenginio qtwebkit-examples qtwebsockets qttranslations mysql-plugin \
            sqlite-plugin \
            docs
}
# new in 5.7.1: qtcharts qtdatavis3d qtgamepad qtpurchasing qtscxml
# removed in 5.7: qtenginio (kept as stubport for 1 or 2 versions)
# these are added to the list either when not building Qt, or when
# building a Qt5 version of the proper version. This is to avoid that
# we define inappropriate stub subports.
if {![info exist building_qt5] || [vercmp ${version} 5.7.0] >= 0} {
    # new stubports to be added to the list for dependents.
    lappend qt5.kde_stubports qtcharts qtdatavis3d qtgamepad qtpurchasing qtscxml
    # qttranslations is moved to its own subport; remove it from the stubports list:
    set qt5.kde_stubports [lsearch -all -inline -not -exact ${qt5.kde_stubports} qttranslations]
}
if {![info exist building_qt5] || [vercmp ${version} 5.8.0] >= 0} {
    lappend qt5.kde_stubports qtdoc qtnetworkauth qtspeech
}
if {![info exist building_qt5] || [vercmp ${version} 5.9.0] >= 0} {
    lappend qt5.kde_stubports qtremoteobjects
    # qt3d is moved to its own subport; remove it from the stubports list:
    set qt5.kde_stubports [lsearch -all -inline -not -exact ${qt5.kde_stubports} qt3d]
}

if {${os.platform} ne "darwin"} {
    lappend qt5.kde_stubports x11
}

global qt5_dependency
global qt5webkit_dependency
if {${os.platform} eq "darwin"} {
    # We define a depspec for port:qt5-kde or port:qt53-kde if we're on OS X 10.6
    if {[info exists building_qt5]} {
        set qt5::pprefix            ${basename}
    } else {
        switch ${os.major} {
            "10" {
                set qt5::pprefix    "qt53-kde"
            }
            default {
                set qt5::pprefix    "qt5-kde"
            }
        }
    }
    # see if the library install exists for some reason, and if so depend on it;
    # if not, depend on the regular framework version
    if {[file exists ${qt_libs_dir}/libQt5Core.${qt_libs_ext}]} {
        ui_warn "QtCore is installed as a regular library (${qt_libs_dir}/libQt5Core.${qt_libs_ext})"
        set qt5_pathlibspec path:libexec/${qt_name}/lib/libQt5Core.${qt_libs_ext}
    } else {
        set qt5_pathlibspec path:libexec/${qt_name}/Library/Frameworks/QtCore.framework/QtCore
    }
    set qt5_dependency ${qt5_pathlibspec}:${qt5::pprefix}
    if {[file exists ${qt_libs_dir}/libQt5WebKit.${qt_libs_ext}]} {
        ui_warn "QtCore is installed as a regular library (${qt_libs_dir}/libQt5WebKit.${qt_libs_ext})"
        set qt5_pathlibspec path:libexec/${qt_name}/lib/libQt5WebKit.${qt_libs_ext}
    } else {
        set qt5_pathlibspec path:libexec/${qt_name}/Library/Frameworks/QtWebKit.framework/QtWebKit
    }
    # prefer the newer, rebooted qt5-webkit
    set qt5webkit_dependency ${qt5_pathlibspec}:qt5-webkit
    set qt5webengine_dependency \
                        path:libexec/${qt_name}/Library/Frameworks/QtWebEngineCore.framework/QtWebEngineCore:${qt5::pprefix}-qtwebengine
} else {
    if {[info exists building_qt5]} {
        set qt5::pprefix            ${basename}
    } else {
        set qt5::pprefix            "qt5-kde"
    }
    set qt5_pathlibspec path:libexec/${qt_name}/lib/libQt5Core.${qt_libs_ext}
    set qt5_dependency ${qt5_pathlibspec}:${qt5::pprefix}
    set qt5webkit_dependency path:libexec/${qt_name}/lib/libQt5WebKit.${qt_libs_ext}:qt5-webkit
    set qt5webengine_dependency \
                        path:libexec/${qt_name}/lib/libQt5WebEngineCore.${qt_libs_ext}:${qt5::pprefix}-qtwebengine
}
if {![info exists building_qt5]} {
    ui_debug "Adding depspec \"${qt5_dependency}\" ([dict get [info frame 0] file])"
    depends_lib-append ${qt5_dependency}
    if {[info exists qt5.depends_qtwebengine] && ${qt5.depends_qtwebengine}} {
        depends_lib-append \
                        ${qt5webengine_dependency}
    }
}

# if {![tbool QT53] && ![tbool qt5.no_LTO_variant] && ![variant_exists LTO]} {
#     if {[info exists building_qt5]} {
#         variant LTO description {Build with Link-Time Optimisation (LTO) (experimental)} {}
#     } else {
#         PortGroup LTO 1.0
#     }
# }

if {![info exists building_qt5]} {
    if {${os.platform} ne "darwin"} {
        configure.ldflags-append        -Wl,-rpath,${qt_libs_dir} -Wl,-rpath,${prefix}/${build_arch}-linux-gnu
    }
}

# standard configure, build and destroot environment, when not building qt5
if {![info exists building_qt5]} {
    # make sure the Qt binaries' directory is in the path, if it is
    # not the current prefix

    if {${qt_dir} ne ${prefix}} {
        configure.env-append    PATH=${qt_dir}/bin:$env(PATH)
        build.env-append        PATH=${qt_dir}/bin:$env(PATH)
        destroot.env-append     PATH=${qt_dir}/bin:$env(PATH)
    }
} else {
    configure.env-append QMAKE_NO_DEFAULTS=""
}

# # standard build environment, when not building qt5
# if {![info exists building_qt5]} {
# #     build.env-append \
# #         QTDIR=${qt_dir} \
# #         QMAKE=${qt_qmake_cmd} \
# #         MOC=${qt_moc_cmd}
# #
# #     if { ![option universal_variant] || ![variant_isset universal] } {
# #         if {${qt_qmake_spec} ne ""} {
# #             build.env-append QMAKESPEC=${qt_qmake_spec}
# #         }
# #     } else {
# #         set merger_build_env(i386)   "QMAKESPEC=${qt_qmake_spec_32}"
# #         set merger_build_env(x86_64) "QMAKESPEC=${qt_qmake_spec_64}"
# #         set merger_arch_flag             yes
# #         set merger_arch_compiler         yes
# #     }
#
#     # make sure the Qt binaries' directory is in the path, if it is
#     # not the current prefix
#
#     if {${qt_dir} ne ${prefix}} {
#         build.env-append    PATH=${qt_dir}/bin:$env(PATH)
#     }
# }

# use PKGCONFIG for Qt discovery in configure scripts
depends_build-delete    port:pkgconfig
depends_build-append    port:pkgconfig

# standard destroot environment
pre-destroot {
    if { ![option universal_variant] || ![variant_isset universal] } {
        destroot.env-append \
            INSTALL_ROOT=${destroot}
    } else {
        foreach arch ${configure.universal_archs} {
            lappend merger_destroot_env($arch) INSTALL_ROOT=${workpath}/destroot-${arch}
        }
    }
}

# # standard destroot environment, when not building qt5
# if {![info exists building_qt5]} {
# #     destroot.env-append \
# #         QTDIR=${qt_dir} \
# #         QMAKE=${qt_qmake_cmd} \
# #         MOC=${qt_moc_cmd}
# #
# #     if { ![option universal_variant] || ![variant_isset universal] } {
# #         if {${qt_qmake_spec} ne ""} {
# #             build.env-append QMAKESPEC=${qt_qmake_spec}
# #         }
# #     } else {
# #         set destroot_build_env(i386)   "QMAKESPEC=${qt_qmake_spec_32}"
# #         set destroot_build_env(x86_64) "QMAKESPEC=${qt_qmake_spec_64}"
# #     }
#
#     # make sure the Qt binaries' directory is in the path, if it is
#     # not the current prefix
#
#     if {${qt_dir} ne ${prefix}} {
#         destroot.env-append PATH=${qt_dir}/bin:$env(PATH)
#     }
# }

# provide a variant to prune provided translations
# make this optional so the locale_select portgroup doesn't need to be made public/official
# the easy way to do that would be to catch the PortGroup statement
# but that will print warnings for everyone who doesn't have the
# the PortGroup installed. Other solution: check for
# [info exist ::env(MACPORTS_QT5KDE_LANGSELECT)] && $::env(MACPORTS_QT5KDE_LANGSELECT)
# Easy solution: check if the config file exists because without that the feature is disabled anyway.
if {[file exists ${prefix}/etc/macports/locales.tcl]} {
    PortGroup   locale_select 1.0
    # Qt translations don't go into ${prefix}/opt/local/share/locale:
    post-destroot {
        if {![info exists keep_languages]} {
            if {[file exists ${destroot}${qt_translations_dir}]} {
                if {[catch {source "${prefix}/etc/macports/locales.tcl"} err]} {
                    ui_error "Error reading ${prefix}/etc/macports/locales.tcl: $err"
                    return -code error "Error reading ${prefix}/etc/macports/locales.tcl"
                }
            }
        }
        if {[info exists keep_languages]} {
            foreach l [glob -nocomplain ${destroot}${qt_translations_dir}/*.qm] {
                set langcomps [split [file rootname [file tail ${l}]] _]
                set simplelang [lindex ${langcomps} end]
                set complang [join [lrange ${langcomps} end-1 end] _]
                if {[lsearch -exact ${keep_languages} ${simplelang}] ne "-1"} {
                    ui_debug "won't delete ${l} (${simplelang})"
                } elseif {[lsearch -exact ${keep_languages} ${complang}] ne "-1"} {
                    ui_debug "won't delete ${l} (${complang})"
                } else {
                    ui_debug "rm ${l}"
                    file delete -force ${l}
                }
            }
        }
    }
}

# convenience function for revision management
proc revbump_for_version {r v {p 0}} {
    global version revision subport os.platform
    if {${p} eq 0 || ${os.platform} eq ${p}} {
        if {[vercmp ${version} ${v}] > 0} {
            ui_error "remove revbump (revision ${r}) for ${subport}"
            pre-configure {
                return -code error "remove revbump (revision ${r}) for ${subport}"
            }
        }
        uplevel set revision ${r}
    }
}

# create a wrapper script in ${prefix}/bin for an application bundle in qt_apps_dir
options qt5.wrapper_env_additions
default qt5.wrapper_env_additions ""

proc qt5.add_app_wrapper {wrappername {bundlename ""} {bundleexec ""} {appdir ""}} {
    global qt_apps_dir destroot prefix os.platform qt5.wrapper_env_additions subport
    if {${os.platform} eq "darwin"} {
        if {${appdir} eq ""} {
            set appdir ${qt_apps_dir}
        }
        if {${bundlename} eq ""} {
            set bundlename ${wrappername}
        }
        if {${bundleexec} eq ""} {
            set bundleexec [file tail ${bundlename}]
        }
    } else {
        # no app bundles on this platform, but provide the same API by pretending there are.
        # If unset, use ${subport} to guess the exec. name because evidently we cannot
        # symlink ${wrappername} onto itself.
        if {${appdir} eq ""} {
            set appdir ${prefix}/bin
        }
        if {${bundlename} eq ""} {
            set bundlename ${subport}
        }
        if {${bundleexec} eq ""} {
            set bundleexec ${bundlename}
        }
    }
    if {${bundleexec} eq "${prefix}/bin/${wrappername}"
            || "${appdir}/${bundleexec}" eq "${prefix}/bin/${wrappername}"} {
        ui_error "qt5.add_app_wrapper: wrapper ${wrappername} would overwrite executable ${bundleexec}: ignoring!"
        return;
    }
    xinstall -m 755 -d ${destroot}${prefix}/bin
    if {![catch {set fd [open "${destroot}${prefix}/bin/${wrappername}" "w"]} err]} {
        # this wrapper exists to a large extent to improve integration of "pure" qt5
        # apps with KF5 apps, in particular through the use of the KDE platform theme plugin
        # Hence the reference to KDE things in the preamble.
        puts ${fd} "#!/bin/sh\n\
            if \[ -r ~/.kf5.env \] ;then\n\
            \t. ~/.kf5.env\n\
            else\n\
            \texport KDE_SESSION_VERSION=5\n\
            fi"
        set wrapper_env_additions "[join ${qt5.wrapper_env_additions}]"
        if {${wrapper_env_additions} ne ""} {
            puts ${fd} "# Additional env. variables specified by port:${subport} :"
            puts ${fd} "export ${wrapper_env_additions}"
            puts ${fd} "#"
        }
        if {${os.platform} eq "darwin"} {
            if {[file dirname ${bundleexec}] eq "."} {
                puts ${fd} "exec \"${appdir}/${bundlename}.app/Contents/MacOS/${bundleexec}\" \"\$\@\""
            } else {
                # fully qualified bundleexec, use "as is"
                puts ${fd} "exec \"${bundleexec}\" \"\$\@\""
            }
        } else {
            global qt_libs_dir
            puts ${fd} "if \[ \"\$\{LD_LIBRARY_PATH\}\" = \"\" \] \;then"
            puts ${fd} "    export LD_LIBRARY_PATH=${prefix}/lib:${qt_libs_dir}"
            puts ${fd} "else"
            puts ${fd} "    export LD_LIBRARY_PATH=\$\{LD_LIBRARY_PATH\}:${prefix}/lib:${qt_libs_dir}"
            puts ${fd} "fi"
            if {[file dirname ${bundleexec}] eq "."} {
                puts ${fd} "exec \"${appdir}/${bundleexec}\" \"\$\@\""
            } else {
                puts ${fd} "exec \"${bundleexec}\" \"\$\@\""
            }
        }
        close ${fd}
        system "chmod 755 ${destroot}${prefix}/bin/${wrappername}"
    } else {
        ui_error "Failed to (re)create \"${destroot}${prefix}/bin/${wrappername}\" : ${err}"
        return -code error ${err}
    }
}

###############################################################################
# define the qt5::component2pathspec array element-by-element instead of in a table;
# using a table wouldn't allow the use of variables (they wouldn't be expanded)
if {${os.platform} eq "darwin"} {
    array set qt5::component2pathspec [list \
        qtwebkit        path:libexec/${qt_name}/Library/Frameworks/QtWebKit.framework/QtWebKit \
        qtwebengine     path:libexec/${qt_name}/Library/Frameworks/QtWebEngine.framework/QtWebEngine \
        qtwebview       path:libexec/${qt_name}/Library/Frameworks/QtWebView.framework/QtWebView \
    ]
    set qt5::component2pathspec(x11) \
                        path:${qt_pkg_config_dir}/Qt5X11Extras.pc
} else {
    array set qt5::component2pathspec [list \
        qtwebkit        path:libexec/${qt_name}/lib/libQt5WebKit.${qt_libs_ext} \
        qtwebengine     path:libexec/${qt_name}/lib/libQt5WebEngineCore.${qt_libs_ext} \
        qtwebview       path:libexec/${qt_name}/lib/libQt5WebView.${qt_libs_ext} \
    ]
}
set qt5::component2pathspec(qt3d)       path:${qt_pkg_config_dir}/Qt53DCore.pc
set qt5::component2pathspec(qttranslations) path:${qt_translations_dir}/qt_en.qm
set qt5::component2pathspec(assistant)  path:${qt_bins_dir}/assistant
set qt5::component2pathspec(webkit)     $qt5::component2pathspec(qtwebkit)

# a procedure for declaring dependencies on Qt5 components, which will expand them
# into the appropriate subports for the Qt5 flavour installed
# e.g. qt5.depends_component qtbase qtsvg qtdeclarative
proc qt5::depends_component_p {deptype args} {
    global qt5::component2pathspec qt5.using_kde os.major qt5.kde_stubports version qt5::pprefix qt5.version qt5.min_version
    # select the Qt5 port prefix, depending on which Qt5 port is installed
    if {![info exists qt5.kde_stubports]} {
        # FIXME!
        ui_error "`qt5.depends_component_p ${deptype} ${args}` shouldn't be called in an inline variant code block"
        return -code error "Unsupported qt5.depends_component usage"
    }
    set is_qt5kde [tbool qt5.using_kde]
    platform darwin {
        if {!${is_qt5kde}} {
            ui_warn "Emulating port:qt5's OS/version matcher - we shouldn't be here!"
            switch ${os.major} {
                "10" {
                    set qt5::pprefix    "qt55"
                }
                "11" {
                    set qt5::pprefix    "qt56"
                }
                "12" {
                    set qt5::pprefix    "qt57"
                }
                "13" {
                    set qt5::pprefix    "qt58"
                }
                "14" {
                    set qt5::pprefix    "qt59"
                }
                "15" {
                    set qt5::pprefix    "qt511"
                }
                default {
                    set qt5::pprefix    "qt5"
                }
            }
        }
    }
    qt5.active_branch
    ui_debug "qt5::depends_component_p, deptype=${deptype} args=$args is_qt5kde=${is_qt5kde} branch=${qt5::active_branch}"
    foreach comp $args {
        set done false
        set portname "${qt5::pprefix}-${comp}"
        switch ${comp} {
            "qt5" {
                if {${is_qt5kde} == 1} {
                    global qt5_dependency
                    # qt5-kde-1.0.tcl exports the exact dependency expression in a variable
                    if {[lsearch -exact [option ${deptype}] ${qt5_dependency}] < 0} {
                        ${deptype}-append ${qt5_dependency}
                    }
                } else {
                    ${deptype}-append port:${qt5::pprefix}
                }
                set done true
            }
            "qtwebkit" -
            "webkit" {
                # this refers to the new version-agnostic port:qt5-webkit
                set portname "qt5-webkit"
            }
            "qtwebengine" -
            "qtwebview" {
                # these components are never stub subports (or possibly so, in the case of QtWebKit)
            }
            default {
                # these components are included port:qt5-kde (and provided as additional stub subports)
                if {${is_qt5kde} == 0 || [lsearch -exact ${qt5.kde_stubports} ${comp}] < 0} {
                    #set done false
                } else {
                    set done true
                }
            }
        }
        if {!${done}} {
            if { [info exists qt5pg::qt5_component_lib(${comp})] } {
                set min_version [lindex $qt5pg::qt5_component_lib(${comp}) 0]
                if {[vercmp ${qt5::active_branch} ${min_version}] < 0} {
                    # the mainstream Qt5 port prints warnings for this, meaning also during portindex operations
                    # I prefer to log an informational message that doesn't appear all the time.
                    ui_info "Component ${comp} does not exist in ${qt5::pprefix} ${qt5::active_branch} (needs Qt${min_version} or better)"
                }
            }
            if {[info exists qt5::component2pathspec] && [info exists qt5::component2pathspec(${comp})]} {
                # an explicit dependency pattern was given, e.g. path:foo
                ui_debug "component ${comp} -> port ${portname} and depspec $qt5::component2pathspec(${comp})"
                ${deptype}-append "$qt5::component2pathspec(${comp}):${portname}"
            } else {
                ${deptype}-append port:${portname}
            }
        }
    }
}

proc qt5.depends_component {args} {
    return [qt5::depends_component_p depends_lib {*}${args}]
}

proc qt5.depends_build_component {args} {
    return [qt5::depends_component_p depends_build {*}${args}]
}

proc qt5.depends_runtime_component {args} {
    return [qt5::depends_component_p depends_run {*}${args}]
}

# this function registers the specified qch file(s) by installing
# symlinks to them into ${destroot}${prefix}/share/doc/qch . This is done only
# when the target directory exists in the install prefix, which in turn means
# that port:qt5-kde*-assistant is installed.
proc qt5.register_qch_files {qchfiles} {
    global prefix destroot
    set qchdir ${prefix}/share/doc/qch
    if {[file exists ${qchdir}] && [file isdirectory ${qchdir}]} {
        foreach d ${qchfiles} {
            if {[file exists ${d}]} {
                xinstall -m 755 -d ${destroot}${qchdir}
                set target [string map [list ${destroot} ""] ${d}]
                ln -s ${target} ${destroot}${qchdir}
            }
        }
    }
}

# store the collection file in the Qt docs dir, not the "assorted misc. collection dir (share/doc/qch)"
set qt5::qch_collection_file "${qt_docs_dir}/MP-qthelp-collection.qhc"

proc qt5.rebuild_mp_qthelp_collection {} {
    global prefix subport qt_bins_dir qt_docs_dir env
    # we'll register entries from share/doc/qch
    set qchdir ${prefix}/share/doc/qch
    set qhcdir [file dirname ${qt5::qch_collection_file}]
    set ret 1
    if {[file exists ${qchdir}] && [file isdirectory ${qchdir}] && [file exists ${qhcdir}] && [file isdirectory ${qhcdir}]} {
        set qhcpfile MP-qthelp-collection.qhcp
        set qhcfile [file tail ${qt5::qch_collection_file}]
        if {(${subport} eq "qt5-kde-assistant") || (${subport} eq "qt5-kde-devel-assistant") \
                || (${subport} eq "qt5-assistant") || (${subport} eq "qt5-assistant-devel")} \
        {
            # always regenerate when (re)installing the Qt Assistant
            set needs_generate yes
        } elseif {[file exists "${qhcdir}/${qhcfile}"]} {
            # only regenerate otherwise when the collection file is out-of-date
            set tDir [file mtime "${qhcdir}"]
            set tchDir [file mtime "${qchdir}"]
            set tFile [file mtime "${qhcdir}/${qhcfile}"]
            set needs_generate [expr ${tDir} > ${tFile} || ${tchDir} > ${tFile}]
            ui_debug "Qt help collection: tDir \"${qhcdir}\"=${tDir} , tchDir \"${qchdir}\"=${tchDir} , File \"${qhcdir}/${qhcfile}\" ${tFile}"
        } else {
            set needs_generate yes
        }
        if {${needs_generate}} {
            if {[file exists ${qt_bins_dir}/qhelpgeneratorng]} {
                set QHELPGENERATOR "${qt_bins_dir}/qhelpgeneratorng"
            } else {
                set QHELPGENERATOR "${qt_bins_dir}/qcollectiongenerator"
            }
            # we only store documentation that's not from Qt in the generated collection file;
            # this appears to be necessary with Qt >= 5.8 to prevent indexing and too-many-open-files errors
            set candidates {}
            foreach q [glob -nocomplain ${qchdir}/*.qch] {
                if {![file exists ${qt_docs_dir}/[file tail ${q}]]} {
                    lappend candidates [file normalize ${q}]
                }
            }
            if {[file exists "${qhcdir}/${qhcfile}"]} {
                file delete -force "${qhcdir}/${qhcfile}"
            }
            set qhc_cache_dir "QtProject/Assistant-MP"
            if {![catch {set fp [open "${qhcdir}/${qhcpfile}" "w"]} err]} {
                # create a collection file corresponding to Qt's own documentation
                ui_msg "--->  (Re)Generating Qt help collection file in ${qhcdir}"
                puts ${fp} "<?xml version=\"1.0\" encoding=\"utf-8\" ?>"
                puts ${fp} "<QHelpCollectionProject version=\"1.0\">"
                puts ${fp} "  <assistant>"
                puts ${fp} "    <title>MacPorts Qt Help Files Collection</title>"
                puts ${fp} "    <cacheDirectory>${qhc_cache_dir}</cacheDirectory>"
                puts ${fp} "    <enableFullTextSearchFallback>true</enableFullTextSearchFallback>"
                puts ${fp} "  </assistant>"
                puts ${fp} "  <docFiles>"
                puts ${fp} "    <register>"
                foreach q [glob -nocomplain ${qhcdir}/*.qch] {
                    puts ${fp} "      <file>[file normalize ${q}]</file>"
                }
                puts ${fp} "    </register>"
                puts ${fp} "  </docFiles>"
                puts ${fp} "</QHelpCollectionProject>"
                close ${fp}
                catch {system -W ${qhcdir} "time ${QHELPGENERATOR} ${qhcpfile} -o ${qhcdir}/${qhcfile}"}
                # this file has to be world-writable, annoyingly
                file attributes ${qhcdir}/${qhcfile} -permissions ugo+rw
                file delete -force ${qhcdir}/${qhcpfile}
            } else {
                ui_warn "cannot create ${qhcdir}/${qhcpfile}: ${err}"
            }
            if {[file exists "${qhcdir}/${qhcfile}"]} {
                # (re)register all candidates
                foreach q ${candidates} {
                    catch {system -W ${qhcdir} "${prefix}/bin/assistant-qt5 -collectionFile ${qhcdir}/${qhcfile} -register [file normalize ${q}]"}
                }
                # be sure the file mdate is updated"
                system "touch \"${qhcdir}/${qhcfile}\""
                set ret 0
            }
            set tempfile "$env(HOME)/.local/share/${qhc_cache_dir}/${qhcfile}"
            if {[file exists ${tempfile}]} {
                ui_debug "Removing temp file ${tempfile}"
                file delete ${tempfile}
            }
        }
    } else {
        ui_debug "qchdir=\"${qchdir}\" and/or qhcdir=\"${qhcdir}\" don't exist as directories, ignoring Qt help collection"
    }
    return ${ret}
}

post-activate {
    qt5.rebuild_mp_qthelp_collection
}

# (hopefully) override the checking function from the stock Qt5 PG:
proc qt5pg::check_min_version {} {
    global qt5.version qt5.min_version
    # make certain qt5.version is set appropriately
    set qt5.version [qt5.active_version]
    if {[vercmp ${qt5.version} ${qt5.min_version}] < 0} {
        ui_debug "Qt version ${qt5.min_version} or above is required, but Qt version ${qt5.version} is installed"
        known_fail yes
        pre-fetch {
            ui_error "Qt version ${qt5.min_version} or above is required, but Qt version ${qt5.version} is installed"
            return -code error "Qt version too old"
        }
    } else {
        ui_debug "Qt version ${qt5.version} satifies requirement ${qt5.min_version} or above"
    }
}
port::register_callback qt5pg::check_min_version

# kate: backspace-indents true; indent-pasted-text true; indent-width 4; keep-extra-spaces true; remove-trailing-spaces modified; replace-tabs true; replace-tabs-save true; syntax Tcl/Tk; tab-indents true; tab-width 4;
