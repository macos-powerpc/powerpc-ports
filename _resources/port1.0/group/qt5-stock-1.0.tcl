# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# This portgroup defines standard settings when using Qt5 (the "stock" Qt5 port).
#
# Usage:
# PortGroup     qt5-stock 1.0

global available_qt_versions
#     qt514 {qt5-qtbase   5.14}
array set available_qt_versions {
    qt5   {qt5-qtbase   5.15}
    qt513 {qt513-qtbase 5.13}
    qt511 {qt511-qtbase 5.11}
    qt59  {qt59-qtbase  5.9}
    qt58  {qt58-qtbase  5.8}
    qt57  {qt57-qtbase  5.7}
    qt56  {qt56-qtbase  5.6}
    qt55  {qt55-qtbase  5.5}
    qt53  {qt53-qtbase  5.3}
}
#qt5-kde {qt5-kde 5.8}

global custom_qt_versions
array set custom_qt_versions {
    phantomjs-qt {phantomjs-qt-qtbase 5.5}
}

# Qt has what is calls reference configurations, which are said to be thoroughly tested
# Qt also has configurations which are "occasionally tested" or are "[d]eployment only"
# see https://doc.qt.io/qt-5/supported-platforms.html#reference-configurations
# see https://doc.qt.io/qt-5/supported-platforms-and-configurations.html

proc qt5.get_default_name {} {
    global os.major

    ###RJVB###
    global os.platform
    if {${os.platform} ne "darwin"} {
        return qt5
    }
    ###RJVB###

    # see https://doc.qt.io/qt-5/supported-platforms-and-configurations.html
    # for older versions, see https://web.archive.org/web/*/http://doc.qt.io/qt-5/supported-platforms-and-configurations.html
    if { ${os.major} <= 7 } {
        #
        # Qt 5 does not support ppc
        # see http://doc.qt.io/qt-5/osx-requirements.html
        #
        return qt55
        #
    } elseif { ${os.major} <= 9 } {
        #
        # Mac OS X Tiger (10.4)
        # Mac OS X Leopard (10.5)
        #
        # never supported by Qt 5
        #
        return qt55
        #
    } elseif { ${os.major} == 10 } {
        #
        # Mac OS X Snow Leopard (10.6)
        #
        #     Qt 5.3: Deployment only
        # Qt 5.0-5.2: Occasionally tested
        #
        return qt53
        #
    } elseif { ${os.major} == 11 } {
        #
        # Mac OS X Lion (10.7)
        #
        # Qt 5.7:  Not Supported and is known not to work
        # Qt 5.6:  Deployment only but seems to work (except QtWebEngine)
        # Qt 5.5:  Occasionally tested
        # Qt 5.4:  Supported
        #
        return qt56
        #
    } elseif { ${os.major} == 12 } {
        #
        # OS X Mountain Lion (10.8)
        #
        # Qt 5.8:  Not Supported
        # Qt 5.7:  Supported (except QtWebEngine)
        # Qt 5.6:  Supported
        #
        return qt57
        #
    } elseif { ${os.major} == 13 } {
        #
        # OS X Mavericks (10.9)
        #
        # Qt 5.9:  Not Supported
        # Qt 5.8:  Supported
        # Qt 5.7:  Supported
        # Qt 5.6:  Supported
        #
        return qt58
        #
    } elseif { ${os.major} == 14 } {
        #
        # OS X Yosemite (10.10)
        #
        # Qt 5.10: Not Supported and QtWebEngine fails
        # Qt 5.9:  Supported
        # Qt 5.8:  Supported
        # Qt 5.7:  Supported
        # Qt 5.6:  Supported
        #
        return qt59
        #
    } elseif { ${os.major} == 15 } {
        #
        # OS X El Capitan (10.11)
        #
        # Qt 5.12: Not Supported
        # Qt 5.11: Supported
        # Qt 5.10: Supported
        # Qt 5.9:  Supported
        # Qt 5.8:  Supported
        # Qt 5.7:  Supported
        # Qt 5.6:  Supported
        #
        return qt511
        #
    } elseif { ${os.major} == 16 } {
        #
        # macOS Sierra (10.12)
        #
        # Qt 5.14: Not Supported
        # Qt 5.13: Supported
        # Qt 5.12: Supported
        # Qt 5.11: Supported
        # Qt 5.10: Supported
        # Qt 5.9:  Supported
        # Qt 5.8:  Supported
        # Qt 5.7:  Not Supported but seems to work
        #
        return qt513
        #
    } elseif { ${os.major} == 17 } {
        #
        # macOS High Sierra (10.13)
        #
        # Qt 5.14: Supported
        # Qt 5.13: Supported
        # Qt 5.12: Supported
        # Qt 5.11: Supported
        # Qt 5.10: Supported
        #
        return qt5
        #
    } elseif { ${os.major} == 18 } {
        #
        # macOS Mojave (10.14)
        #
        # Qt 5.14: Supported
        # Qt 5.13: Supported
        # Qt 5.12: Supported
        #
        return qt5
        #
    } elseif { ${os.major} == 19 } {
        #
        # macOS Catalina (10.15)
        #
        # Qt 5.14: Supported
        # Qt 5.13: Not Supported but seems to work
        # Qt 5.12: Not Supported but seems to work
        #
        return qt5
        #
    } else {
        #
        # macOS ??? (???)
        #
        return qt5
    }
}

global qt5.name qt5.base_port qt5.version

# get the latest Qt version that runs on current OS configuration
set qt5.name       [qt5.get_default_name]
set qt5.base_port  [lindex $available_qt_versions(${qt5.name}) 0]
set qt5.version    [lindex $available_qt_versions(${qt5.name}) 1]

# check if another version of Qt is installed
foreach {qt_test_name qt_test_info} [array get available_qt_versions] {
    set qt_test_base_port [lindex ${qt_test_info} 0]
    if {![catch {set installed [lindex [registry_active ${qt_test_base_port}] 0]}]} {
        ui_debug "Already installed Qt5 version: ${qt_test_name} (${qt_test_base_port})"
        set qt5.name       ${qt_test_name}
        set qt5.base_port  ${qt_test_base_port}
        set qt5.version    [lindex $installed 1]
    }
}

if {[info exists name]} {
    # check to see if this is a Qt port being built
    foreach {qt_test_name qt_test_info} [array get available_qt_versions] {
        if {${qt_test_name} eq ${name}} {
            set qt5.name       ${name}
            set qt5.base_port  [lindex $available_qt_versions(${qt5.name}) 0]
            set qt5.version    [lindex $available_qt_versions(${qt5.name}) 1]
        }
    }
}

if {[info exists qt5.custom_qt_name]} {
    set qt5.name       ${qt5.custom_qt_name}
    set qt5.base_port  [lindex $custom_qt_versions(${qt5.name}) 0]
    set qt5.version    [lindex $custom_qt_versions(${qt5.name}) 1]
}

if {[tbool just_want_qt5_version_info]} {
    ui_debug "just_want_qt5_version_info is true, returning"
    return
}

# standard install directory
global qt_dir
if {[info exists qt5.custom_qt_name]} {
    set qt_dir          ${prefix}/libexec/${qt5.custom_qt_name}
} else {
    ###RJVB###
    if {${os.platform} eq "darwin"} {
        set qt_dir       ${prefix}/libexec/qt5
    } else {
        # let's use this prefix for now...
        set qt_dir       ${prefix}/libexec/qt512
    }
}
###RJVB###

# standard Qt non-.app executables directory
global qt_bins_dir
set qt_bins_dir         ${qt_dir}/bin

# standard Qt includes directory
global qt_includes_dir
set qt_includes_dir     ${qt_dir}/include

# standard Qt libraries directory
global qt_libs_dir
set qt_libs_dir         ${qt_dir}/lib

# standard Qt libraries directory
global qt_frameworks_dir
set qt_frameworks_dir   ${qt_libs_dir}

global qt_archdata_dir
set qt_archdata_dir  ${qt_dir}

# standard Qt plugins directory
global qt_plugins_dir
set qt_plugins_dir      ${qt_archdata_dir}/plugins

# standard Qt imports directory
global qt_imports_dir
set qt_imports_dir      ${qt_archdata_dir}/imports

# standard Qt qml directory
global qt_qml_dir
set qt_qml_dir          ${qt_archdata_dir}/qml

# standard Qt data directory
global qt_data_dir
set qt_data_dir         ${qt_dir}

# standard Qt documents directory
global qt_docs_dir
set qt_docs_dir         ${qt_data_dir}/doc

# standard Qt translations directory
global qt_translations_dir
set qt_translations_dir ${qt_data_dir}/translations

# standard Qt sysconf directory
global qt_sysconf_dir
set qt_sysconf_dir      ${qt_dir}/etc/xdg

# standard Qt examples directory
global qt_examples_dir
set qt_examples_dir     ${qt_dir}/examples

# standard Qt tests directory
global qt_tests_dir
set qt_tests_dir        ${qt_dir}/tests

# data used by qmake
global qt_host_data_dir
set qt_host_data_dir    ${qt_dir}

# standard Qt mkspecs directory
global qt_mkspecs_dir
set qt_mkspecs_dir      ${qt_dir}/mkspecs

# standard Qt .app executables directory, if created
global qt_apps_dir
set qt_apps_dir         ${applications_dir}/Qt5

# standard CMake module directory for Qt-related files
#global qt_cmake_module_dir
set qt_cmake_module_dir ${qt_libs_dir}/cmake

# standard qmake command location
global qt_qmake_cmd
set qt_qmake_cmd        ${qt_dir}/bin/qmake

# standard moc command location
global qt_moc_cmd
set qt_moc_cmd          ${qt_dir}/bin/moc

# standard uic command location
global qt_uic_cmd
set qt_uic_cmd          ${qt_dir}/bin/uic

# standard lrelease command location
global qt_lrelease_cmd
set qt_lrelease_cmd     ${qt_dir}/bin/lrelease

# standard lupdate command location
global qt_lupdate_cmd
set qt_lupdate_cmd     ${qt_dir}/bin/lupdate

# standard PKGCONFIG path
global qt_pkg_config_dir
set qt_pkg_config_dir   ${qt_libs_dir}/pkgconfig

###RJVB###
global qt_install_registry
set qt_install_registry ${qt_dir}/registry
###RJVB###

namespace eval qt5pg {
    ############################################################################### Component Format
    #
    # "Qt Component Name" {
    #     Qt version introduced
    #     Qt version removed
    #     file installed by component
    #     blank if module; "-plugin" if plugin
    # }
    #
    # module info found at https://doc.qt.io/qt-5/qtmodules.html
    #
    ###############################################################################
    array set qt5_component_lib {
        qt3d {
            5.5
            6.0
            lib/pkgconfig/Qt53DCore.pc
            ""
        }
        qtbase {
            5.0
            6.0
            lib/pkgconfig/Qt5Core.pc
            ""
        }
        qtcanvas3d {
            5.5
            5.13
            libexec/qt5/qml/QtCanvas3D/libqtcanvas3d.dylib
            ""
        }
        qtcharts {
            5.7
            6.0
            lib/pkgconfig/Qt5Charts.pc
            ""
        }
        qtconnectivity {
            5.2
            6.0
            lib/pkgconfig/Qt5Bluetooth.pc
            ""
        }
        qtdatavis3d {
            5.7
            6.0
            lib/pkgconfig/Qt5DataVisualization.pc
            ""
        }
        qtdeclarative {
            5.0
            6.0
            lib/pkgconfig/Qt5Qml.pc
            ""
        }
        qtdeclarative-render2d {
            5.7
            5.8
            lib/cmake/Qt5Quick/Qt5Quick_ContextPlugin.cmake
            ""
        }
        qtdoc {
            5.0
            6.0
            libexec/qt5/doc/qtdoc.qch
            ""
        }
        qtgamepad {
            5.7
            6.0
            lib/pkgconfig/Qt5Gamepad.pc
            ""
        }
        qtenginio {
            5.3
            5.7
            lib/pkgconfig/Enginio.pc
            ""
        }
        qtgraphicaleffects {
            5.0
            6.0
            libexec/qt5/qml/QtGraphicalEffects/libqtgraphicaleffectsplugin.dylib
            ""
        }
        qtimageformats {
            5.0
            6.0
            lib/cmake/Qt5Gui/Qt5Gui_QTiffPlugin.cmake
            ""
        }
        qtlocation {
            5.2
            6.0
            lib/pkgconfig/Qt5Location.pc
            ""
        }
        qtlottie {
            5.13
            6.0
            lib/cmake/Qt5Bodymovin/Qt5BodymovinConfig.cmake
            ""
        }
        qtmacextras {
            5.2
            6.0
            lib/pkgconfig/Qt5MacExtras.pc
            ""
        }
        qtmultimedia {
            5.0
            6.0
            lib/pkgconfig/Qt5Multimedia.pc
            ""
        }
        qtnetworkauth {
            5.8
            6.0
            lib/pkgconfig/Qt5NetworkAuth.pc
            ""
        }
        qtpurchasing {
            5.7
            6.0
            lib/pkgconfig/Qt5Purchasing.pc
            ""
        }
        qtquick1 {
            5.0
            5.6
            lib/pkgconfig/Qt5Declarative.pc
            ""
        }
        qtquick3d {
            5.14
            6.0
            lib/pkgconfig/Qt5Quick3D.pc
            ""
        }
        qtquickcontrols {
            5.1
            6.0
            libexec/qt5/qml/QtQuick/Controls/libqtquickcontrolsplugin.dylib
            ""
        }
        qtquickcontrols2 {
            5.6
            6.0
            lib/pkgconfig/Qt5QuickControls2.pc
            ""
        }
        qtquicktimeline {
            5.14
            6.0
            libexec/qt5/qml/QtQuick/Timeline/libqtquicktimelineplugin.dylib
            ""
        }
        qtremoteobjects {
            5.9
            6.0
            lib/pkgconfig/Qt5RemoteObjects.pc
            ""
        }
        qtscript {
            5.0
            6.0
            lib/pkgconfig/Qt5Script.pc
            ""
        }
        qtscxml {
            5.7
            6.0
            lib/pkgconfig/Qt5Scxml.pc
            ""
        }
        qtsensors {
            5.1
            6.0
            lib/pkgconfig/Qt5Sensors.pc
            ""
        }
        qtserialbus {
            5.6
            6.0
            lib/pkgconfig/Qt5SerialBus.pc
            ""
        }
        qtserialport {
            5.1
            6.0
            lib/pkgconfig/Qt5SerialPort.pc
            ""
        }
        qtspeech {
            5.8
            6.0
            lib/pkgconfig/Qt5TextToSpeech.pc
            ""
        }
        qtsvg {
            5.0
            6.0
            lib/pkgconfig/Qt5Svg.pc
            ""
        }
        qttools {
            5.0
            6.0
            lib/pkgconfig/Qt5Designer.pc
            ""
        }
        qttranslations {
            5.0
            6.0
            libexec/qt5/translations/qt_ar.qm
            ""
        }
        qtvirtualkeyboard {
            5.7
            6.0
            lib/cmake/Qt5Gui/Qt5Gui_QVirtualKeyboardPlugin.cmake
            ""
        }
        qtwebchannel {
            5.4
            6.0
            lib/pkgconfig/Qt5WebChannel.pc
            ""
        }
        qtwebengine {
            5.4
            6.0
            lib/pkgconfig/Qt5WebEngine.pc
            ""
        }
        qtwebglplugin {
            5.10
            6.0
            lib/cmake/Qt5Gui/Qt5Gui_QWebGLIntegrationPlugin.cmake
            ""
        }
        qtwebkit {
            5.0
            6.0
            lib/pkgconfig/Qt5WebKit.pc
            ""
        }
        qtwebkit-examples {
            5.0
            6.0
            libexec/qt5/examples/webkitwidgets/webkitwidgets.pro
            ""
        }
        qtwebsockets {
            5.3
            6.0
            lib/pkgconfig/Qt5WebSockets.pc
            ""
        }
        qtwebview {
            5.6
            6.0
            lib/pkgconfig/Qt5WebView.pc
            ""
        }
        qtxmlpatterns {
            5.0
            6.0
            lib/pkgconfig/Qt5XmlPatterns.pc
            ""
        }
        sqlite-plugin {
            5.0
            6.0
            lib/cmake/Qt5Sql/Qt5Sql_QSQLiteDriverPlugin.cmake
            "-plugin"
        }
        psql-plugin {
            5.0
            6.0
            lib/cmake/Qt5Sql/Qt5Sql_QPSQLDriverPlugin.cmake
            "-plugin"
        }
        mysql-plugin {
            5.0
            6.0
            lib/cmake/Qt5Sql/Qt5Sql_QMYSQLDriverPlugin.cmake
            "-plugin"
        }
    }
    #
    #
    #qtjsbackend {
    #    5.0
    #    5.2
    #    ""
    #}
    #
    # qtwebkit: official support dropped in 5.6.0
    #           as of 5.9, still maintained by community
    if {${os.platform} ne "darwin"} {
        set qt5_component_lib(qtx11extras) {
            5.2
            6.0
            lib/pkgconfig/Qt5X11Extras.pc
            ""
        }
    }
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
    return
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

# use PKGCONFIG for Qt discovery in configure scripts
depends_build-delete    port:pkgconfig
depends_build-append    port:pkgconfig

# standard qmake spec
# other platforms required
#     see http://doc.qt.io/qt-5/supported-platforms.html
#     and http://doc.qt.io/QtSupportedPlatforms/index.html
options qt_qmake_spec
global qt_qmake_spec_32
global qt_qmake_spec_64
compiler.blacklist-append *gcc-4.*

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
    default supported_archs "ppc ppc64"
}

###RJVB###
if {${os.platform} eq "darwin"} {
###RJVB###
if {[vercmp ${qt5.version} 5.9]>=0} {
    # in version 5.9, QT changed how it handles multiple architectures
    # see http://web.archive.org/web/20170621174843/http://doc.qt.io/qt-5/osx.html

    set qt_qmake_spec_32 macx-g++
    set qt_qmake_spec_64 macx-g++

    destroot.env-append INSTALL_ROOT=${destroot}
} else {
    # no universal binary support in Qt 5 versions < 5.9
    #     see http://lists.qt-project.org/pipermail/interest/2012-December/005038.html
    #     and https://bugreports.qt.io/browse/QTBUG-24952
    # override universal_setup found in portutil.tcl so it uses muniversal PortGroup
    # see https://trac.macports.org/ticket/51643
    PortGroup muniversal 1.0
    default universal_archs_supported {ppc ppc64}

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

    set qt_qmake_spec_32 macx-g++-32
    set qt_qmake_spec_64 macx-g++
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
            if { ${configure.build_arch} eq "ppc" } {
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
rename ::eval_variants ::real_qt5_eval_variants
proc eval_variants {variations} {
    global qt5.kde_variant
    if { ![variant_exists qt5kde] && [tbool qt5.kde_variant] } {
        variant qt5kde description {use Qt patched for KDE compatibility} {}
    }
    uplevel ::real_qt5_eval_variants $variations
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
    }
}
port::register_callback qt5pg::check_min_version

unset private_building_qt5
