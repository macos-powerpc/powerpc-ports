# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# $Id: qt4-1.0.tcl 124176 2014-08-20 07:57:31Z ryandesign@macports.org $

# Copyright (c) 2010-2014 The MacPorts Project
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
# This portgroup defines standard settings when using Qt4.
#
# Usage:
# PortGroup     qt4 1.0

# define this here so it will also be available if we end up including the mainstream qt4-mac portgroup
proc qt_branch {} {
    global version
    return [join [lrange [split ${version} .] 0 1] .]
}

# check if by chance we're being loaded while the user has the mainstream qt4 port installed
# TODO: one day I may want to account for Linux here (when moving to a KF5 Plasma desktop system?)
if {![info exists building_qt4] || ![info exists name] || (${name} ne "qt4-mac" && ${name} ne "qt4-mac-devel")
    || ${subport} eq "${name}-transitional"} {
    # we're not building Qt4, and aren't a Qt4 port either; we must be included by a port depending on Qt4
    # Use the pkgconfig files as an indicator which Qt4 port flavour is installed:
    if {![file exists ${prefix}/lib/pkgconfig/QtCore.pc]} {
        if {[info exists depends_lib]} {
            set curdeps ${depends_lib}
        } else {
            set curdeps ""
        }
        PortGroup   qt4-mac 1.0
        if {[info exists depends_lib] && (${curdeps} eq "" || [string first ${curdeps} ${depends_lib}] >= 0)} {
            set qt4_dependency [string map {${curdeps} ""} ${depends_lib}]
            ui_warn "depends_libs change: ${qt4_dependency}"
        } else {
            set qt4_dependency port:qt4-mac
        }
        ui_warn "Using the mainstream/official Qt4 portgroup"
        return -code ok
        ui_msg "This should never print!"
    }
}

# check for +debug variant of this port, and make sure Qt was
# installed with +debug as well; if not, error out.
platform darwin {
    pre-extract {
        if {[variant_exists debug] && \
            [variant_isset debug] && \
           ![info exists building_qt4]} {
            if {![file exists ${qt_frameworks_dir}/QtCore.framework/QtCore_debug]} {
                return -code error "\n\nERROR:\n\
In order to install this port as +debug,
Qt4 must also be installed with +debug.\n"
            }
        }
    }
}

# standard Qt4 name
global qt_name
set qt_name             qt4

# standard install directory
    global qt_dir
    global qt_dir_rel
# standard Qt documents directory
    global qt_docs_dir
# standard Qt plugins directory
    global qt_plugins_dir
# standard Qt mkspecs directory
    global qt_mkspecs_dir
# standard Qt imports directory
    global qt_imports_dir
# standard Qt includes directory
    global qt_includes_dir
# standard Qt libraries directory
    global qt_libs_dir
# standard Qt libraries directory
    global qt_frameworks_dir
    global qt_frameworks_dir_rel
# standard Qt non-.app executables directory
    global qt_bins_dir
# standard Qt data directory
    global qt_data_dir
# standard Qt translations directory
    global qt_translations_dir
# standard Qt sysconf directory
    global qt_sysconf_dir
# standard Qt examples directory
    global qt_examples_dir
# standard Qt demos directory
    global qt_demos_dir
# standard CMake module directory for Qt-related files
    global qt_cmake_module_dir
# standard qmake command location
    global qt_qmake_cmd
# standard moc command location
    global qt_moc_cmd
# standard uic command location
    global qt_uic_cmd
# standard lrelease command location
    global qt_lrelease_cmd

global qt4_is_concurrent
if {![variant_isset exclusive]} {
    if {![info exists building_qt4] || ![info exists name] || (${name} ne "qt4-mac" && ${name} ne "qt4-mac-devel") || ${subport} eq "${name}-transitional"} {
        #exec ls -l ${prefix}/libexec/${qt_name}/bin/qmake
        if {[file exists ${prefix}/libexec/${qt_name}/bin/qmake]} {
            # we have a "concurrent" install, which means we must look for the various components
            # in different locations (esp. qmake)
            set qt4_is_concurrent   1
            set auto_concurrent 1
        }
    } else {
        if {![info exists qt4_is_concurrent]} {
            ui_debug "NB:\nQt4 has been or will be installed in concurrent mode\n"
        }
        # we're asking for the standard concurrent install. No need to guess anything, give the user what s/he wants
        set qt4_is_concurrent   1
        set auto_concurrent     1
    }
}

if {[info exists qt4_is_concurrent]} {
    set qt_dir              ${prefix}/libexec/${qt_name}
    set qt_dir_rel          libexec/${qt_name}
    set qt_share_dir        ${prefix}/share
    set qt_docs_dir         ${qt_share_dir}/doc/${qt_name}
    set qt_plugins_dir      ${qt_share_dir}/${qt_name}/plugins
    set qt_mkspecs_dir      ${qt_share_dir}/${qt_name}/mkspecs
    set qt_imports_dir      ${qt_share_dir}/${qt_name}/imports
    set qt_includes_dir     ${prefix}/include/${qt_name}
    set qt_libs_dir         ${qt_dir}/lib
    set qt_frameworks_dir   ${qt_dir}/Library/Frameworks
    set qt_bins_dir         ${qt_dir}/bin
    set qt_data_dir         ${qt_share_dir}/${qt_name}
    set qt_translations_dir ${qt_share_dir}/${qt_name}/translations
    set qt_sysconf_dir      ${prefix}/etc/${qt_name}
    #set qt_examples_dir     ${prefix}/share/${qt_name}/examples
    set qt_examples_dir     ${applications_dir}/Qt4/examples
    set qt_demos_dir        ${applications_dir}/Qt4/demos
    # no need to change the cmake_module_dir, though I'd have preferred to
    # put it into ${prefix}/lib/cmake as qt4-mac also does, and which is the place Linux uses
    set qt_cmake_module_dir ${qt_share_dir}/cmake/Modules
    set qt_qmake_cmd        ${qt_dir}/bin/qmake
    set qt_moc_cmd          ${qt_dir}/bin/moc
    set qt_uic_cmd          ${qt_dir}/bin/uic
    set qt_lrelease_cmd     ${qt_dir}/bin/lrelease
} else {
    set qt_dir              ${prefix}
    set qt_dir_rel          ""
    set qt_share_dir        ${qt_dir}/share
    set qt_docs_dir         ${qt_share_dir}/doc/${qt_name}
    set qt_plugins_dir      ${qt_share_dir}/${qt_name}/plugins
    set qt_mkspecs_dir      ${qt_share_dir}/${qt_name}/mkspecs
    set qt_imports_dir      ${qt_share_dir}/${qt_name}/imports
    set qt_includes_dir     ${qt_dir}/include
    set qt_libs_dir         ${qt_dir}/lib
    set qt_frameworks_dir   ${qt_dir}/Library/Frameworks
    set qt_bins_dir         ${qt_dir}/bin
    set qt_data_dir         ${qt_share_dir}/${qt_name}
    set qt_translations_dir ${qt_share_dir}/${qt_name}/translations
    set qt_sysconf_dir      ${qt_dir}/etc/${qt_name}
    set qt_examples_dir     ${qt_share_dir}/${qt_name}/examples
    set qt_demos_dir        ${qt_share_dir}/${qt_name}/demos
    set qt_cmake_module_dir ${qt_share_dir}/cmake/Modules
    set qt_qmake_cmd        ${qt_dir}/bin/qmake
    set qt_moc_cmd          ${qt_dir}/bin/moc
    set qt_uic_cmd          ${qt_dir}/bin/uic
    set qt_lrelease_cmd     ${qt_dir}/bin/lrelease
}
set qt_frameworks_dir_rel   ${qt_dir_rel}/Library/Frameworks

# standard Qt .app executables directory, if created
global qt_apps_dir
set qt_apps_dir         ${applications_dir}/Qt4

# standard qmake spec
global qt_qmake_spec
set qt_qmake_spec       macx-g++

# standard PKGCONFIG path
global qt_pkg_config_dir
set qt_pkg_config_dir   ${prefix}/lib/pkgconfig

# standard cmake info for Qt4
global qt_cmake_defines
set qt_cmake_defines    \
    "-DQT_QT_INCLUDE_DIR=${qt_includes_dir} \
     -DQT_QMAKESPEC=${qt_qmake_spec} \
     -DQT_ZLIB_LIBRARY=${prefix}/lib/libz.dylib \
     -DQT_PNG_LIBRARY=${prefix}/lib/libpng.dylib"

# set Qt understood arch types, based on user preference
options qt_arch_types
default qt_arch_types {[string map {i386 x86} [get_canonical_archs]]}

# allow for depending on either qt4-mac and qt4-mac-devel, simultaneously

if {![info exists building_qt4]} {
    global qt4_dependency
    if {${os.platform} eq "darwin"} {

        # see if the framework install exists, and if so depend on it;
        # if not, depend on the library version

        if {[info exists qt4_is_concurrent]} {
            if {[file exists ${qt_frameworks_dir}/QtCore.framework/QtCore]} {
                set qt4_dependency path:libexec/${qt_name}/Library/Frameworks/QtCore.framework/QtCore:qt4-mac
                #depends_lib-append path:libexec/${qt_name}/Library/Frameworks/QtCore/QtCore:qt4-mac
            } else {
                set qt4_dependency path:libexec/${qt_name}/lib/libQtCore.4.dylib:qt4-mac
                #depends_lib-append path:libexec/${qt_name}/lib/libQtCore.4.dylib:qt4-mac
            }
        } else {
            if {[file exists ${qt_frameworks_dir}/QtCore.framework/QtCore]} {
                set qt4_dependency path:Library/Frameworks/QtCore.framework/QtCore:qt4-mac
                #depends_lib-append path:Library/Frameworks/QtCore/QtCore:qt4-mac
            } else {
                set qt4_dependency path:lib/libQtCore.4.dylib:qt4-mac
                #depends_lib-append path:lib/libQtCore.4.dylib:qt4-mac
            }
        }

    } else {
        set qt4_dependency      path:lib/libQtCore.so.4:qt4-x11
        #depends_lib-append      path:lib/libQtCore.so.4:qt4-x11
    }
    depends_lib-append  ${qt4_dependency}
}

# standard configure environment, when not building qt4

if {![info exists building_qt4]} {
    configure.env-append \
        QTDIR=${qt_dir} \
        QMAKE=${qt_qmake_cmd} \
        QMAKESPEC=${qt_qmake_spec} \
        MOC=${qt_moc_cmd}

    # make sure the Qt binaries' directory is in the path, if it is
    # not the current prefix

    if {${qt_dir} ne ${prefix}} {
        configure.env-append PATH=${qt_dir}/bin:$env(PATH)
    }
} else {
    configure.env-append QMAKE_NO_DEFAULTS=""
}

# standard build environment, when not building qt4

if {![info exists building_qt4]} {
    build.env-append \
        QTDIR=${qt_dir} \
        QMAKE=${qt_qmake_cmd} \
        QMAKESPEC=${qt_qmake_spec} \
        MOC=${qt_moc_cmd}

    # make sure the Qt binaries' directory is in the path, if it is
    # not the current prefix

    if {${qt_dir} ne ${prefix}} {
        build.env-append    PATH=${qt_dir}/bin:$env(PATH)
        configure.pkg_config_path-append ${qt_pkg_config_dir}
    }
} else {
    build.env-append QMAKE_NO_DEFAULTS=""
}

# use PKGCONFIG for Qt discovery in configure scripts
depends_build-delete    port:pkgconfig
depends_build-append    port:pkgconfig

# standard destroot environment

destroot.env-append \
    INSTALL_ROOT=${destroot} \
    DESTDIR=${destroot}

# standard destroot environment, when not building qt4

if {![info exists building_qt4]} {
    destroot.env-append \
        QTDIR=${qt_dir} \
        QMAKE=${qt_qmake_cmd} \
        QMAKESPEC=${qt_qmake_spec} \
        MOC=${qt_moc_cmd}

    # make sure the Qt binaries' directory is in the path, if it is
    # not the current prefix

    if {${qt_dir} ne ${prefix}} {
        destroot.env-append PATH=${qt_dir}/bin:$env(PATH)
    }
} else {
    destroot.env-append QMAKE_NO_DEFAULTS=""
}

# create a wrapper script in ${prefix}/bin for an application bundle in qt_apps_dir
options qt4.wrapper_env_additions
default qt4.wrapper_env_additions ""

proc qt4.add_app_wrapper {wrappername {bundlename ""} {bundleexec ""} {appdir ""}} {
    global qt_apps_dir destroot prefix os.platform qt4.wrapper_env_additions subport
    if {${appdir} eq ""} {
        set appdir ${qt_apps_dir}
    }
    xinstall -m 755 -d ${destroot}${prefix}/bin
    if {![catch {set fd [open "${destroot}${prefix}/bin/${wrappername}" "w"]} err]} {
        # this wrapper exists to a large extent to improve integration of "pure" qt4
        # apps with KF5 apps, in particular through the use of the KDE platform theme plugin
        # Hence the reference to KDE things in the preamble.
        puts ${fd} "#!/bin/sh\n\
            if \[ -r ~/.kde4.env \] ;then\n\
            \t. ~/.kde4.env\n\
            else\n\
            \texport KDE_SESSION_VERSION=4\n\
            fi"
        set wrapper_env_additions "[join ${qt4.wrapper_env_additions}]"
        if {${wrapper_env_additions} ne ""} {
            puts ${fd} "# Additional env. variables specified by port:${subport} :"
            puts ${fd} "export ${wrapper_env_additions}"
            puts ${fd} "#"
        }
        if {${os.platform} eq "darwin"} {
            if {${bundlename} eq ""} {
                set bundlename ${wrappername}
            }
            if {${bundleexec} eq ""} {
                set bundleexec ${bundlename}
            }
            puts ${fd} "exec \"${appdir}/${bundlename}.app/Contents/MacOS/${bundleexec}\" \"\$\@\""
        } else {
            global qt_libs_dir
            # no app bundles on this platform, but provide the same API by pretending there are.
            # If unset, use ${subport} to guess the exec. name because evidently we cannot
            # symlink ${wrappername} onto itself.
            if {${bundlename} eq ""} {
                set bundlename ${subport}
            }
            if {${bundleexec} eq ""} {
                set bundleexec ${bundlename}
            }
            puts ${fd} "export LD_LIBRARY_PATH=\$\{LD_LIBRARY_PATH\}:${prefix}/lib:${qt_libs_dir}"
            puts ${fd} "exec \"${appdir}/${bundleexec}\" \"\$\@\""
        }
        close ${fd}
        system "chmod 755 ${destroot}${prefix}/bin/${wrappername}"
    } else {
        ui_error "Failed to (re)create \"${destroot}${prefix}/bin/${wrappername}\" : ${err}"
        return -code error ${err}
    }
}
