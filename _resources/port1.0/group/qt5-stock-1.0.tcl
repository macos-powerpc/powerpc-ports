# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# This portgroup defines standard settings when using Qt5 (the "stock" Qt5 port).
#
# Usage:
# PortGroup     qt5-stock 1.0

PortGroup   qt5_variables 1.0

if {[tbool just_want_qt5_version_info]} {
    ui_warn "just_want_qt5_version_info is true, but obsolete and ignored nowadays"
    #return
}

###########################################################################################
# Check what Qt5 port and PortGroup we should be using, based on indicated port preference,
# what is already installed and OS version.
# Given that ports exist for multiple Qt5 versions it is easier to distinguish port:qt5 and
# port:qt5-kde from differences in install layout than from active installed portnames.

# first, check if port:qt5-kde or a port:qt5-kde-devel is installed, or if we're on Mac OS X 10.6
# NB: the qt5-kde-devel ports may never exist officially in MacPorts but is used locally by KF5 port maintainers!
# NB2 : ${prefix} isn't set by portindex but registry_active can be used!!
if {![variant_isset qt5stock_kde] && ([file exists ${prefix}/include/qt5/QtCore/QtCore] || ${os.major} == 10
        || ([catch {registry_active "qt5-kde"}] == 0 || [catch {registry_active "qt5-kde-devel"}] == 0)) } {
    set qt5PGname "qt5-kde"
} elseif {[file exists ${prefix}/libexec/qt5/plugins/platforms/libqcocoa.dylib]
        && [file type ${prefix}/libexec/qt5/plugins] eq "directory"} {
    # qt5-qtbase is installed: Qt5 has been installed through a standard port:qt5 port
    # (checking if "plugins" is a directory is probably redundant)
    # We're already in the correct PortGroup
    set qt5PGname "qt5"
} elseif {([info exists qt5.prefer_kde] || [variant_isset qt5kde]) && ![variant_isset qt5stock_kde]} {
    # The calling port has indicated a preference and no Qt5 port is installed already
    # transfer control to qt5-kde-1.0.tcl
    ui_debug "port:qt5-kde has been requested explicitly"
    set qt5PGname "qt5-kde"
} else {
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

switch -exact ${qt5PGname} {
    qt5-kde {
        # Qt5 has been installed through port:qt5-kde or port:qt5-kde-devel or we're on 10.6
        # transfer control to qt5-kde-1.0.tcl
        ui_debug "Qt5 is provided by port:qt5-kde; transferring to PortGroup qt5-kde 1.0"
        PortGroup           ${qt5PGname} 1.0
        return
    }
    default {
        # default situation: we're already in the correct PortGroup, unless:
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

if {[file exists "${qt_install_registry}/qt5-qtbase+qt5stock_kde"]} {
    if {![variant_exists qt5stock_kde]} {
        variant qt5stock_kde description {default variant set for the \"stock\" port:qt5* adapted for KDE, and ports that depend on them} {}
    }
    # it should no longer be necessary to set qt5kde but we will continue to do so for now.
    if {[variant_isset qt5stock_kde]} {
        ui_debug "+qt5stock_kde is set for port:${subport}"
    } else {
        ui_debug "+qt5stock_kde is not yet set but will be for port:${subport}"
    }
    default_variants    +qt5stock_kde
}
# borrowed from qt5-kde-1.0.tcl:
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
# add rpaths on ~darwin
if {![info exists building_qt5]} {
    if {${os.platform} ne "darwin"} {
        configure.ldflags-append -Wl,-rpath,${qt_libs_dir} -Wl,-rpath,${prefix}/${build_arch}-linux-gnu
    }
}

# create a wrapper script in ${prefix}/bin for an application bundle in qt_apps_dir
options qt5.wrapper_env_additions
default qt5.wrapper_env_additions ""

proc qt5.add_app_wrapper {wrappername {bundlename ""} {bundleexec ""} {appdir ""}} {
    global qt_dir qt_apps_dir destroot prefix os.platform qt5.wrapper_env_additions subport
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
        set wrapper_env_additions "[join ${qt5.wrapper_env_additions}]"
        if {${wrapper_env_additions} ne ""} {
            puts ${fd} "# Additional env. variables specified by port:${subport} :"
            puts ${fd} "export ${wrapper_env_additions}"
            puts ${fd} "#"
        }
        if {${os.platform} eq "darwin"} {
            if {[file dirname ${bundleexec}] eq "."} {
                puts ${fd} "exec ${qt_dir}/thisQt.sh \"${appdir}/${bundlename}.app/Contents/MacOS/${bundleexec}\" \"\$\@\""
            } else {
                # fully qualified bundleexec, use "as is"
                puts ${fd} "exec ${qt_dir}/thisQt.sh \"${bundleexec}\" \"\$\@\""
            }
        } else {
            if {[file dirname ${bundleexec}] eq "."} {
                puts ${fd} "exec ${qt_dir}/thisQt.sh \"${appdir}/${bundleexec}\" \"\$\@\""
            } else {
                puts ${fd} "exec ${qt_dir}/thisQt.sh \"${bundleexec}\" \"\$\@\""
            }
        }
        close ${fd}
        system "chmod 755 ${destroot}${prefix}/bin/${wrappername}"
    } else {
        ui_error "Failed to (re)create \"${destroot}${prefix}/bin/${wrappername}\" : ${err}"
        return -code error ${err}
    }
}

###########################################################################################

if {[tbool just_want_qt5_variables]} {
    ui_warn "just_want_qt5_variables is true, but obsolete and ignored nowadays"
    #return
}

# a procedure for declaring dependencies on Qt5 components, which will expand them
# into the appropriate subports for the Qt5 flavour installed
# e.g. qt5.depends_component qtsvg qtdeclarative
proc qt5.depends_component {args} {
    global qt5_private_components
    foreach comp ${args} {
        lappend qt5_private_components ${comp}
    }
}
proc qt5.depends_build_component {args} {
    global qt5_private_build_components
    foreach comp ${args} {
        lappend qt5_private_build_components ${comp}
    }
}
proc qt5.depends_runtime_component {args} {
    global qt5_private_runtime_components
    foreach comp ${args} {
        lappend qt5_private_runtime_components ${comp}
    }
}

options qt5.kde_variant
default qt5.kde_variant no

options qt5.min_version
default qt5.min_version 5.0

# valid value for Qt variable QMAKE_MAC_SDK
options qt5.mac_sdk
default qt5.mac_sdk     {[qt5pg::qmake_mac_sdk]}

# use PKGCONFIG for Qt discovery in configure scripts
depends_build-delete    path:bin/pkg-config:pkgconfig port:pkgconfig
depends_build-append    path:bin/pkg-config:pkgconfig

# standard qmake spec
# other platforms required
#     see http://doc.qt.io/qt-5/supported-platforms.html
#     and http://doc.qt.io/QtSupportedPlatforms/index.html
options qt_qmake_spec
global qt_qmake_spec_32
global qt_qmake_spec_64
compiler.blacklist-append *gcc*

if {[vercmp ${qt5.version} 5.15]>=0} {
    # only qt5 5.15.x has so far been built as arm64 on MacPorts
    default supported_archs "x86_64 arm64"
} elseif {[vercmp ${qt5.version} 5.10]>=0} {
    # see https://bugreports.qt.io/browse/QTBUG-58401
    # RJVB: add arm64 because what the heck...
    default supported_archs "x86_64 arm64"
} else {
    # no PPC support in Qt 5
    #     see http://lists.qt-project.org/pipermail/interest/2012-December/005038.html
    default supported_archs "i386 x86_64"
}

###RJVB###
if {${os.platform} eq "darwin"} {
###RJVB###
if {[vercmp ${qt5.version} 5.9]>=0} {
    # in version 5.9, QT changed how it handles multiple architectures
    # see http://web.archive.org/web/20170621174843/http://doc.qt.io/qt-5/osx.html

    set qt_qmake_spec_32 macx-clang
    set qt_qmake_spec_64 macx-clang

    destroot.env-append INSTALL_ROOT=${destroot}
} else {
    # no universal binary support in Qt 5 versions < 5.9
    #     see http://lists.qt-project.org/pipermail/interest/2012-December/005038.html
    #     and https://bugreports.qt.io/browse/QTBUG-24952
    # override universal_setup found in portutil.tcl so it uses muniversal PortGroup
    # see https://trac.macports.org/ticket/51643
    PortGroup muniversal 1.0
    default universal_archs_supported {i386 x86_64}

    # standard destroot environment
    pre-destroot {
        global merger_destroot_env
        if {![variant_exists universal]  || ![variant_isset universal]} {
            destroot.env-append \
                INSTALL_ROOT=${destroot}
        } else {
            foreach arch ${configure.universal_archs} {
                lappend merger_destroot_env($arch) INSTALL_ROOT=${workpath}/destroot-${arch}
            }
        }
    }

    set qt_qmake_spec_32 macx-clang-32
    set qt_qmake_spec_64 macx-clang
}
###RJVB###
} elseif {${os.platform} eq "linux"} {
    if {[string match *clang* ${configure.compiler}]} {
        set qt_qmake_spec_32    linux-clang
        set qt_qmake_spec_64    linux-clang
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
        set qt_qmake_spec_32    linux-g++
        set qt_qmake_spec_64    linux-g++-64
#         compiler.blacklist-append \
#                                 clang
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
###RJVB###

default qt_qmake_spec {[qt5pg::get_default_spec]}

namespace eval qt5pg {
    proc get_default_spec {} {
        global configure.build_arch qt_qmake_spec_32 qt_qmake_spec_64
        if {![variant_exists universal]  || ![variant_isset universal]} {
            if { ${configure.build_arch} eq "i386" } {
                return ${qt_qmake_spec_32}
            } else {
                return ${qt_qmake_spec_64}
            }
        } else {
            return ${qt_qmake_spec_64}
        }
    }
}

set private_building_qt5 false
# check to see if this is a Qt base port being built
foreach {qt_test_name qt_test_info} [array get available_qt_versions] {
    set qt_test_base_port [lindex ${qt_test_info} 0]
    if {${qt_test_base_port} eq ${subport}} {
        set private_building_qt5 true
    }
}
foreach {qt_test_name qt_test_info} [array get custom_qt_versions] {
    set qt_test_base_port [lindex ${qt_test_info} 0]
    if {${qt_test_base_port} eq ${subport}} {
        set private_building_qt5 true
    }
}

if {!${private_building_qt5}} {
    pre-configure {
        ui_debug "qt5 PortGroup: Qt is provided by ${qt5.name}"

        if { [variant_exists qt5kde] && [variant_isset qt5kde] } {
            if { ${qt5.base_port} ne "qt5-kde" } {
                ui_error "qt5 PortGroup: Qt is installed but not qt5-kde, as is required by this variant"
                ui_error "qt5 PortGroup: please run `sudo port uninstall --follow-dependents ${qt5.base_port} and try again"
                return -code error "improper Qt installed"
            }
        } elseif { ![info exists qt5.custom_qt_name] } {
            if { ${qt5.name} ne [qt5.get_default_name] } {
                # see https://wiki.qt.io/Qt-Version-Compatibility
                ui_warn "qt5 PortGroup: default Qt for this platform is [qt5.get_default_name] but ${qt5.name} is installed"
            }
            if { ${qt5.name} ne "qt5" } {
                ui_warn "Qt dependency is not the latest version but may be the latest supported on your OS"
            }
            if { ${os.platform} eq "darwin" && ${os.major} < 11 } {
                ui_warn "Qt dependency is not supported on this platform and may not build"
            }
        }
    }
}

# add qt5kde variant if one does not exist and one is requested via qt5.kde_variant
# variant is added in eval_variants so that qt5.kde_variant can be set anywhere in the Portfile
if {[catch {rename ::eval_variants ::real_qt5_eval_variants} err]} {
    ui_debug "Can't overload the eval_variants procedure: ${err}"
} else {
    pre-fetch {
        ui_debug "qt5-stock-1.0 PG overloaded the eval_variants procedure!"
    }
    proc eval_variants {variations} {
        global qt5.kde_variant
        if { ![variant_exists qt5kde] && [tbool qt5.kde_variant] } {
            variant qt5kde description {use Qt patched for KDE compatibility} {}
        }
        uplevel ::real_qt5_eval_variants $variations
    }
}

namespace eval qt5pg {
    proc register_dependents {} {
        global qt5_private_components qt5_private_build_components qt5_private_runtime_components qt5.name qt5.version qt5.min_version

        if { ![exists qt5_private_components] } {
            # no Qt components have been requested
            # qt5.depends_component has never been called
            set qt5_private_components ""
        }
        if { ![exists qt5_private_build_components] } {
            # qt5.depends_build_component has never been called
            set qt5_private_build_components ""
        }
        if { ![exists qt5_private_runtime_components] } {
            # qt5.depends_build_component has never been called
            set qt5_private_runtime_components ""
        }

        if { [variant_exists qt5kde] && [variant_isset qt5kde] } {
            set qt_kde_name qt5-kde

            depends_lib-append port:${qt_kde_name}

            foreach component ${qt5_private_components} {
                switch -exact ${component} {
                    qtwebkit -
                    qtwebengine -
                    qtwebview -
                    qtenginio {
                        # these components are subports
                        depends_lib-append port:${qt_kde_name}-${component}
                    }
                    default {
                        # qt5-kde provides all components except those above
                    }
                }
            }
            foreach component ${qt5_private_build_components} {
                switch -exact ${component} {
                    qtwebkit -
                    qtwebengine -
                    qtwebview -
                    qtenginio {
                        # these components are subports
                        depends_run-append port:${qt_kde_name}-${component}
                    }
                    default {
                        # qt5-kde provides all components except those above
                    }
                }
            }
            foreach component ${qt5_private_runtime_components} {
                switch -exact ${component} {
                    qtwebkit -
                    qtwebengine -
                    qtwebview -
                    qtenginio {
                        # these components are subports
                        depends_build-append port:${qt_kde_name}-${component}
                    }
                    default {
                        # qt5-kde provides all components except those above
                    }
                }
            }
        } else {
            # ![variant_isset qt5kde]
            foreach component "qtbase ${qt5_private_components}" {
                if { ${component} eq "qt5" } {
                    depends_lib-append path:share/doc/qt5/README.txt:${qt5.name}
                } elseif { [info exists qt5pg::qt5_component_lib(${component})] } {
                    set component_info $qt5pg::qt5_component_lib(${component})
                    set path           [lindex ${component_info} 2]
                    set version_intro  [lindex ${component_info} 0]
                    if {[vercmp ${qt5.version} ${version_intro}] >= 0} {
                        depends_lib-append path:${path}:${qt5.name}-${component}
                    } else {
                        if {[vercmp ${qt5.version} ${qt5.min_version}] >= 0} {
                            ui_warn "${component} does not exist in Qt ${qt5.version}"
                        } else {
                            # port will fail during pre-fetch
                        }
                    }
                } else {
                    return -code error "unknown component ${component}"
                }
            }
            foreach component ${qt5_private_build_components} {
                if { [info exists qt5pg::qt5_component_lib(${component})] } {
                    set component_info $qt5pg::qt5_component_lib(${component})
                    set path           [lindex ${component_info} 2]
                    set version_intro  [lindex ${component_info} 0]
                    if {[vercmp ${qt5.version} ${version_intro}] >= 0} {
                        depends_build-append path:${path}:${qt5.name}-${component}
                    } else {
                        if {[vercmp ${qt5.version} ${qt5.min_version}] >= 0} {
                            ui_warn "${component} does not exist in Qt ${qt5.version}"
                        } else {
                            # port will fail during pre-fetch
                        }
                    }
                } else {
                    return -code error "unknown component ${component}"
                }
            }
            foreach component ${qt5_private_runtime_components} {
                if { [info exists qt5pg::qt5_component_lib(${component})] } {
                    set component_info $qt5pg::qt5_component_lib(${component})
                    set path           [lindex ${component_info} 2]
                    set version_intro  [lindex ${component_info} 0]
                    if {[vercmp ${qt5.version} ${version_intro}] >= 0} {
                        depends_run-append path:${path}:${qt5.name}-${component}
                    } else {
                        if {[vercmp ${qt5.version} ${qt5.min_version}] >= 0} {
                            ui_warn "${component} does not exist in Qt ${qt5.version}"
                        } else {
                            # port will fail during pre-fetch
                        }
                    }
                } else {
                    return -code error "unknown component ${component}"
                }
            }
        }
    }
}

if {!${private_building_qt5}} {
    port::register_callback qt5pg::register_dependents
}

proc qt5pg::check_min_version {} {
    global qt5.version qt5.min_version
    if {[vercmp ${qt5.version} ${qt5.min_version}] < 0} {
        known_fail yes
        pre-fetch {
            ui_error "Qt version ${qt5.min_version} or above is required, but Qt version ${qt5.version} is installed"
            return -code error "Qt version too old"
        }
    } else {
        ui_debug "Qt version ${qt5.version} satifies requirement ${qt5.min_version} or above"
    }
}

# get a valid value for Qt variable QMAKE_MAC_SDK
proc qt5pg::qmake_mac_sdk {} {
    global  configure.sdkroot \
            configure.sdk_version

    if {${configure.sdkroot} eq "" || [file tail ${configure.sdkroot}] eq "MacOSX.sdk"} {
        return "macosx"
    } elseif {[string first . ${configure.sdk_version}] == -1} {
        set sdks [lsort -command vercmp -decreasing [glob -nocomplain [file rootname ${configure.sdkroot}]*.sdk]]
        set best_sdk_version [string map {MacOSX ""} [file rootname [file tail [lindex $sdks 0]]]]
        return macosx${best_sdk_version}
    } else {
        return macosx${configure.sdk_version}
    }
}

port::register_callback qt5pg::check_min_version

unset private_building_qt5
