# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4
# $Id: kde4-1.1.tcl 133799 2015-03-11 19:45:29Z mk@macports.org $

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
# Usage:
# PortGroup     kde4 1.1

# Use CMake and Qt4 port groups
PortGroup               cmake 1.1
PortGroup               qt4 1.0

namespace eval kde4 {
    # our directory:
    variable currentportgroupdir [file dirname [dict get [info frame 0] file]]
}

# setup all KDE4 ports to build in a separate directory from the source:
cmake.out_of_source         yes

configure.args-delete   -DCMAKE_BUILD_TYPE=Release
# force cmake to use the compiler flags passed through CFLAGS, CXXFLAGS etc. in the environment
configure.args-append   -DCMAKE_BUILD_TYPE:STRING=MacPorts \
                        -DCMAKE_STRIP:FILEPATH=/bin/echo \
                        -DCMAKE_USE_RELATIVE_PATHS:BOOL=ON \
                        -DQT_QMAKE_EXECUTABLE=${qt_qmake_cmd}
configure.env-append    QTDIR=${qt_dir}
build.env-append        QTDIR=${qt_dir}
destroot.env-append     QTDIR=${qt_dir}

# Install the kdelibs headerfiles in their own directory to prevent clashes with KF5 headers
set kde4.include_prefix KDE4
set kde4.include_dirs   ${prefix}/include/${kde4.include_prefix}
set kde4.legacy_prefix  ${prefix}/libexec/kde4-legacy
set kde4.cmake_module_dir \
                        ${prefix}/lib/cmake/${kde4.include_prefix}

set kde4.mirror         https://download.kde.org/Attic/

# set compiler to Apple's GCC 4.2
switch ${os.platform}_${os.major} {
    darwin_8 {
        configure.compiler  apple-gcc-4.2
    }
    darwin_9 {
        configure.compiler  gcc-4.2
    }
}

# Certain ports will need to be installed in "KF5 compatibility mode" if they are to co-exist
# with their KF5 counterparts. Call `kde4.use_legacy_prefix` to activate this mode, *before*
# the configure step is executed and taking care not to undo the effects.
# If a legacy prefix is used, the global variable kde4.legacy_prefix_restored will be defined
# and set to 'no'; it is set to 'yes' by kde4.restore_from_legacy_prefix .
# An optional boolean argument deactivates the automatic calling of kde4.restore_from_legacy_prefix .
proc kde4.use_legacy_prefix {{autorestore 1}} {
    upvar #0 kde4.legacy_prefix_restored restored
    upvar #0 kde4.legacy_prefix_autorestore dorestore
    global prefix
    global kde4.legacy_prefix
    global kde4.include_dirs
    configure.pre_args-replace \
                    -DCMAKE_INSTALL_PREFIX=${prefix} -DCMAKE_INSTALL_PREFIX=${kde4.legacy_prefix}
#     configure.args-replace \
#                     -DCMAKE_INSTALL_RPATH=${prefix}/lib -DCMAKE_INSTALL_RPATH="${prefix}/lib\;${kde4.legacy_prefix}/lib"
    cmake.install_rpath-append \
                    ${kde4.legacy_prefix}/lib
    # changing the install prefix will override the KDE4_INCLUDE_INSTALL_DIR path normally set
    # to ${kde4.include_dirs} by kdelibs4's cmake modules. Make sure to override it back to that setting.
    configure.args-append \
                    -DINCLUDE_INSTALL_DIR=${kde4.include_dirs}
    set restored no
    if {(${autorestore} eq 1) || (${autorestore} eq yes)} {
        set dorestore yes
    } else {
        set dorestore no
    }
}

# kde4.restore_from_legacy_prefix is called from the post-destroot phase of a port that uses
# KF5 compatibility mode. That mode is very indiscriminate, installing everything into the
# legacy_prefix initially. Most things will actually have to be moved back out into the
# regular prefix. This procedure automates what can be automated, but may also overshoot
# its goal.
# See the post-destroot block at the end of this file.
# After completion, the global variable kde4.legacy_prefix_restored will be set to 'yes'.
# This procedure is called automatically after calling kde4.use_legacy_prefix ; it can be
# avoided by calling `kde4.use_legacy_prefix no`
# This procedure is bound to evolve.
proc kde4.restore_from_legacy_prefix {} {
    global destroot
    global prefix
    global kde4.legacy_prefix
    global kde4.cmake_module_dir
    upvar #0 kde4.legacy_prefix_restored restored
    if {[info exists restored] && (${restored} eq yes)} {
        ui_debug "kde4.restore_from_legacy_prefix already called"
        return
    }
    if {[file exists ${destroot}${kde4.legacy_prefix}/lib/kde4]} {
        # move back the kparts, libexec etc. to where they should be
        file rename ${destroot}${kde4.legacy_prefix}/lib/kde4 ${destroot}${prefix}/lib/kde4
    }
    if {[file exists ${destroot}${kde4.legacy_prefix}/include]} {
        ui_msg "WARNING: include directory \"${destroot}${kde4.legacy_prefix}/include\" exists!"
#         # move back the include directory to where it should be;
#         # first delete the include directory that was created for us and should be empty:
#         file delete -force ${destroot}${prefix}/include
#         file rename ${destroot}${kde4.legacy_prefix}/include ${destroot}${prefix}/include
    }
    if {[file exists ${destroot}${kde4.legacy_prefix}/share]} {
        # move back the share directory to where it should be;
        foreach J [glob -nocomplain ${destroot}${kde4.legacy_prefix}/share/*] {
            set d [file tail ${J}]
            file rename ${J} ${destroot}${prefix}/share/${d}
        }
    }
    if {[file exists ${destroot}${kde4.legacy_prefix}/lib/cmake]} {
        # move back the cmake modules to where they should be
#         file rename ${destroot}${kde4.legacy_prefix}/lib/cmake ${destroot}${prefix}/lib/cmake
        xinstall -m 755 -d [file dirname ${destroot}${kde4.cmake_module_dir}]
        file rename ${destroot}${kde4.legacy_prefix}/lib/cmake ${destroot}${kde4.cmake_module_dir}
    }
    # check if the "share" symlink is present: it's installed by port:kdelibs4 (which itself doesn't
    # have need for a kf5compat variant or the legacy_prefix).
    if {![file exists ${kde4.legacy_prefix}/share]} {
        ui_msg "WARNING: the installed port:kdelibs4 does not provide ${kde4.legacy_prefix}/share!"
        notes-append "WARNING: the installed port:kdelibs4 does not provide ${kde4.legacy_prefix}/share!"
    }
    set restored yes
}

# # augment the CMake module lookup path, if necessary depending on
# # where Qt4 is installed.
# 
# # prepend our own (new) install location for cmake modules:
# cmake.module_path-append ${kde4.cmake_module_dir}
# if {${qt_cmake_module_dir} ne ${cmake_share_module_dir}} {
#     cmake.module_path-append \
#                         ${qt_cmake_module_dir}
# }
# ui_debug "cmake.module_path: [cmake::module_path]"
# 
# # standard configure args; virtually all KDE ports use CMake and Qt4.
# configure.args-append   -DBUILD_doc=OFF \
#                         -DBUILD_docs=OFF \
#                         -DBUILD_SHARED_LIBS=ON \
#                         -DBUNDLE_INSTALL_DIR=${applications_dir}/KDE4 \
#                         -DKDE_DISTRIBUTION_TEXT=\"MacPorts\/Mac OS X\" \
#                         ${qt_cmake_defines}

# # explicitly define certain headers and libraries, to avoid
# # conflicts with those installed into system paths by the user.
# # 20151015 RJVB : these are handled in FindMySQL.cmake :
# #                         -DMYSQL_INCLUDE_DIR=${prefix}/include/mysql5/mysql \
# #                         -DMYSQL_LIB_DIR=${prefix}/lib/mysql5/mysql \
# # 20151015 RJVB : these are best left to port select ...
# #                         -DMYSQLCONFIG_EXECUTABLE=${prefix}/bin/mysql_config5 \
# #                         -DMYSQLD_EXECUTABLE=${prefix}/libexec/mysqld \
# 
# configure.args-append   -DDOCBOOKXSL_DIR=${prefix}/share/xsl/docbook-xsl-nons \
#                         -DGETTEXT_INCLUDE_DIR=${prefix}/include \
#                         -DGETTEXT_LIBRARY=${prefix}/lib/libgettextlib.dylib \
#                         -DGIF_INCLUDE_DIR=${prefix}/include \
#                         -DGIF_LIBRARY=${prefix}/lib/libgif.dylib \
#                         -DJASPER_INCLUDE_DIR=${prefix}/include \
#                         -DJASPER_LIBRARY=${prefix}/lib/libjasper.dylib \
#                         -DJPEG_INCLUDE_DIR=${prefix}/include \
#                         -DJPEG_LIBRARY=${prefix}/lib/libjpeg.dylib \
#                         -DLBER_LIBRARIES=${prefix}/lib/liblber.dylib \
#                         -DLDAP_INCLUDE_DIR=${prefix}/include \
#                         -DLDAP_LIBRARIES=${prefix}/lib/libldap.dylib \
#                         -DLIBEXSLT_INCLUDE_DIR=${prefix}/include \
#                         -DLIBEXSLT_LIBRARIES=${prefix}/lib/libexslt.dylib \
#                         -DLIBICALSS_LIBRARY=${prefix}/lib/libicalss.dylib \
#                         -DLIBICAL_INCLUDE_DIRS=${prefix}/include \
#                         -DLIBICAL_LIBRARY=${prefix}/lib/libical.dylib \
#                         -DLIBINTL_INCLUDE_DIR=${prefix}/include \
#                         -DLIBINTL_LIBRARY=${prefix}/lib/libintl.dylib \
#                         -DLIBXML2_INCLUDE_DIR=${prefix}/include/libxml2 \
#                         -DLIBXML2_LIBRARIES=${prefix}/lib/libxml2.dylib \
#                         -DLIBXML2_XMLLINT_EXECUTABLE=${prefix}/bin/xmllint \
#                         -DLIBXSLT_INCLUDE_DIR=${prefix}/include \
#                         -DLIBXSLT_LIBRARIES=${prefix}/lib/libxslt.dylib \
#                         -DOPENAL_INCLUDE_DIR=/System/Library/Frameworks/OpenAL.framework/Headers \
#                         -DOPENAL_LIBRARY=/System/Library/Frameworks/OpenAL.framework \
#                         -DPNG_INCLUDE_DIR=${prefix}/include \
#                         -DPNG_PNG_INCLUDE_DIR=${prefix}/include \
#                         -DPNG_LIBRARY=${prefix}/lib/libpng.dylib \
#                         -DTIFF_INCLUDE_DIR=${prefix}/include \
#                         -DTIFF_LIBRARY=${prefix}/lib/libtiff.dylib \
#                         -DSOPRANO_PREFIX=${prefix}
# 
# # These two can be removed (see #46240):
# #                        -DQCA2_INCLUDE_DIR=${prefix}/include/QtCrypto \
# #                        -DQCA2_LIBRARIES=${prefix}/lib/libqca.dylib \

# standard variant for building documentation
variant docs description "Build documentation" {
    depends_build-append    bin:doxygen:doxygen
    configure.args-delete   -DBUILD_doc=OFF -DBUILD_docs=OFF
}

if {[info exist ::env(MACPORTS_COMPRESS_WORKDIR)] && $::env(MACPORTS_COMPRESS_WORKDIR)} {
    post-build {
        if {[file exists ${prefix}/bin/afsctool]} {
            ui_msg "--->  Compressing build directory ..."
            if {[catch {system "${prefix}/bin/afsctool -cfvv -8 -J${build.jobs} ${build.dir} 2>&1"} result context]} {
                ui_msg "Compression failed: ${result}, ${context}; port:afsctool is probably installed without support for parallel compression"
            } else {
                ui_debug "Compressing ${build.dir}: ${result}"
            }
        }
    }
}

post-destroot {
    if {[info exists kde4.legacy_prefix_autorestore]} {
        # check if we need to do automatic restoring (the default). We do that here because this post-destroot
        # block should be the first such block. In other words, the calling Portfile should not yet have had
        # a chance to modify the destroot in ways that kde4.restore_from_legacy_prefix might overwrite.
        # kde4.restore_from_legacy_prefix checks itself if it already completed once.
        if {(${kde4.legacy_prefix_autorestore} eq yes) || (${kde4.legacy_prefix_autorestore} eq 1)} {
            ui_debug "doing requested auto kde4.restore_from_legacy_prefix (${kde4.legacy_prefix_autorestore})"
            kde4.restore_from_legacy_prefix
        }
    }
    if {![info exists kde4.legacy_prefix_restored] || ${kde4.legacy_prefix_restored} eq no} {
        # move the port's cmake modules to ${kde4.cmake_module_dir}. This is an operation that might
        # be overwritten if the Portfile calls kde4.restore_from_legacy_prefix afterwards, hence the
        # call to that function just above.
        if {[file exists ${destroot}${prefix}/lib/cmake]} {
            # avoid a loop construct here (and a direct rename may not work, e.g. lib/cmake -> lib/cmake/KDE4 won't)
            # move the directory out of the way
            file rename ${destroot}${prefix}/lib/cmake ${destroot}/cmake_temp_dir
            # create the parent for ${kde4.cmake_module_dir}
            xinstall -m 755 -d [file dirname ${destroot}${kde4.cmake_module_dir}]
            # move the temp dir into place
            file rename ${destroot}/cmake_temp_dir ${destroot}${kde4.cmake_module_dir}
        }
    }
}

post-activate {
    if {[file exists ${prefix}/bin/kbuildsycoca4]} {
        ui_msg "--->  Updating KDE's global desktop file system configuration cache ..."
        system "${prefix}/bin/kbuildsycoca4 --global"
    }
}

# create a .macports-$subport-configure.cmd file containing the cmake invocation details
cmake.save_configure_cmd "install log"

notes-append "
Don't forget that dbus needs to be started as the local\
user (not with sudo) before any KDE programs will launch.
To start it run the following command:
 launchctl load -w /Library/LaunchAgents/org.freedesktop.dbus-session.plist
"

# create a wrapper script in ${prefix}/bin for an application bundle in ${applications_dir}/KDE4
options kde4.wrapper_env_additions
default kde4.wrapper_env_additions ""
proc kde4.add_app_wrapper {wrappername {bundlename ""} {bundleexec ""}} {
    global applications_dir os.platform kde4.wrapper_env_additions

    qt4.wrapper_env_additions "[join ${kde4.wrapper_env_additions}]"
    if {${os.platform} eq "darwin"} {
        if {${bundlename} eq ""} {
            set bundlename ${wrappername}
        }
        if {${bundleexec} eq ""} {
            set bundleexec ${bundlename}
        }
    } else {
        global qt_libs_dir
        # no app bundles on this platform, but provide the same API by pretending there are.
        # If unset, use subport to guess the exec. name because evidently we cannot
        # symlink ${wrappername} onto itself.
        if {${bundlename} eq ""} {
            set bundlename ${subport}
        }
        if {${bundleexec} eq ""} {
            set bundleexec ${bundlename}
        }
    }
    qt4.add_app_wrapper ${wrappername} ${bundlename} ${bundleexec} ${applications_dir}/KDE4
}

proc kde4::configure_build {} {

    global prefix applications_dir subport os.platform
    global qt_cmake_defines qt_cmake_module_dir
    global cmake_share_module_dir
    global kde4.cmake_module_dir

    # Make sure to not use any already installed headers and libraries;
    # these are set in CPATH and LIBRARY_PATH anyway.
    configure.ldflags-delete  -L${prefix}/lib
    configure.cppflags-delete -I${prefix}/include

    # Automoc added as build dependency here as most, if not all kde
    # programs currently need it. The automoc port, which includes this
    # PortGroup overrides depends_build, removing "port:automoc" to
    # prevent a cyclic dependency
    if {${subport} ne "automoc"} {
        ui_debug "kde4-1.1 PG : depends_build-append    port:automoc"
        depends_build-delete \
                            port:automoc
        depends_build-append \
                            port:automoc
    }

    # Phonon added as library dependency here as most, if not all KDE
    # programs current need it.  The phonon port, which includes this
    # PortGroup overrides depends_lib, removing "port:phonon" to prevent a
    # cyclic dependency
    depends_lib-delete      port:phonon
    depends_lib-append      port:phonon

    # augment the CMake module lookup path, if necessary depending on
    # where Qt4 is installed.
    if {${qt_cmake_module_dir} ne ${cmake_share_module_dir}} {
        set cmake_module_path ${kde4.cmake_module_dir}\;${cmake_share_module_dir}\;${qt_cmake_module_dir}
    } else {
        # prepend our own (new) install location for cmake modules:
        set cmake_module_path ${kde4.cmake_module_dir}\;${cmake_share_module_dir}
    }
    configure.args-delete -DCMAKE_MODULE_PATH=${cmake_share_module_dir}
    configure.args-append -DCMAKE_MODULE_PATH="${cmake_module_path}" \
                          -DCMAKE_PREFIX_PATH="${cmake_module_path}"

    # standard configure args; virtually all KDE ports use CMake and Qt4.
    configure.args-append   -DBUILD_doc=OFF \
                            -DBUILD_docs=OFF \
                            -DBUILD_SHARED_LIBS=ON \
                            -DBUNDLE_INSTALL_DIR=${applications_dir}/KDE4 \
                            -DKDE_DISTRIBUTION_TEXT=\"MacPorts\/Mac OS X\" \
                            ${qt_cmake_defines}

    # explicitly define certain headers and libraries, to avoid
    # conflicts with those installed into system paths by the user.
    set shext [expr {${os.platform} eq "darwin" ? "dylib" : "so"}]
    configure.args-append   -DDOCBOOKXSL_DIR=${prefix}/share/xsl/docbook-xsl-nons \
                            -DGETTEXT_INCLUDE_DIR=${prefix}/include \
                            -DGETTEXT_LIBRARY=${prefix}/lib/libgettextlib.${shext} \
                            -DGIF_INCLUDE_DIR=${prefix}/include \
                            -DGIF_LIBRARY=${prefix}/lib/libgif.${shext} \
                            -DJASPER_INCLUDE_DIR=${prefix}/libexec/jasper2/include \
                            -DJASPER_LIBRARY=${prefix}/libexec/jasper2/lib/libjasper.${shext} \
                            -DJPEG_INCLUDE_DIR=${prefix}/include \
                            -DJPEG_LIBRARY=${prefix}/lib/libjpeg.${shext} \
                            -DLBER_LIBRARIES=${prefix}/lib/liblber.${shext} \
                            -DLDAP_INCLUDE_DIR=${prefix}/include \
                            -DLDAP_LIBRARIES=${prefix}/lib/libldap.${shext} \
                            -DLIBEXSLT_INCLUDE_DIR=${prefix}/include \
                            -DLIBEXSLT_LIBRARIES=${prefix}/lib/libexslt.${shext} \
                            -DLIBICALSS_LIBRARY=${prefix}/lib/libicalss.${shext} \
                            -DLIBICAL_INCLUDE_DIRS=${prefix}/include \
                            -DLIBICAL_LIBRARY=${prefix}/lib/libical.${shext} \
                            -DLIBINTL_INCLUDE_DIR=${prefix}/include \
                            -DLIBINTL_LIBRARY=${prefix}/lib/libintl.${shext} \
                            -DLIBXML2_INCLUDE_DIR=${prefix}/include/libxml2 \
                            -DLIBXML2_LIBRARIES=${prefix}/lib/libxml2.${shext} \
                            -DLIBXML2_XMLLINT_EXECUTABLE=${prefix}/bin/xmllint \
                            -DLIBXSLT_INCLUDE_DIR=${prefix}/include \
                            -DLIBXSLT_LIBRARIES=${prefix}/lib/libxslt.${shext} \
                            -DOPENAL_INCLUDE_DIR=/System/Library/Frameworks/OpenAL.framework/Headers \
                            -DOPENAL_LIBRARY=/System/Library/Frameworks/OpenAL.framework \
                            -DPNG_INCLUDE_DIR=${prefix}/include \
                            -DPNG_PNG_INCLUDE_DIR=${prefix}/include \
                            -DPNG_LIBRARY=${prefix}/lib/libpng.${shext} \
                            -DTIFF_INCLUDE_DIR=${prefix}/include \
                            -DTIFF_LIBRARY=${prefix}/lib/libtiff.${shext} \
                            -DSOPRANO_PREFIX=${prefix}

    # These two can be removed (see #46240):
    #                        -DQCA2_INCLUDE_DIR=${prefix}/include/QtCrypto \
    #                        -DQCA2_LIBRARIES=${prefix}/lib/libqca.${shext} \
    # These ones are obsolete, as purely based on mysql5 paths (see #49296):
    #                        -DMYSQLD_EXECUTABLE=${prefix}/libexec/mysqld \
    #                        -DMYSQL_INCLUDE_DIR=${prefix}/include/mysql5/mysql \
    #                        -DMYSQL_LIB_DIR=${prefix}/lib/mysql5/mysql \
    #                        -DMYSQLCONFIG_EXECUTABLE=${prefix}/bin/mysql_config5 \

}
port::register_callback kde4::configure_build
