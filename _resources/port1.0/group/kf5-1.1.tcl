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
# PortGroup     kf5 1.1

namespace eval kf5 {
    # our directory:
    set currentportgroupdir [file dirname [dict get [info frame 0] file]]
    # ports may (have to) include us more than once
    if {![info exists includecounter]} {
        set includecounter  0
    }
}

if {${kf5::includecounter} == 0} {
    if {![info exists kf5.no_qt5_prefer_kde]} {
        # let's live dangerously:
        set qt5.prefer_kde  1
    }
    if {[info proc qt5.depends_component] eq ""} {
        PortGroup       qt5 1.0
    }
    PortGroup           cmake 1.1
    PortGroup           active_variants 1.1

    pre-fetch {
        if {${os.platform} eq "darwin" && ${os.major} < 13} {
            ui_error "KF5 no longer supports Mac OS versions older than 10.9"
            return -code error "KF5 requires 10.9 or newer"
        }
    }

    if {![info exists qt5.using_kde] || !${qt5.using_kde}} {
        pre-fetch {
            ui_warn "It is strongly advised to install KF5 ports against port:qt5-kde or port:qt5-kde-devel; any other configuration is not supported."
        }
        pre-configure {
            ui_warn "It is strongly advised to install KF5 ports against port:qt5-kde or port:qt5-kde-devel; any other configuration is not supported."
        }
                notes-append "It is strongly advised to install KF5 ports against port:qt5-kde or port:qt5-kde-devel; any other configuration is not supported."
        # pull in a build dependency that port:qt5-kde includes by default in the main port:
        qt5.depends_component \
                        qttools
    }
}

if {${os.platform} eq "darwin" && ${os.major} <= 13} {
#     depends_fetch-append \
#                     bin:wget:wget
    # avoid certificate issues on kde.org
    fetch.ignore_sslcert    yes
#     fetch {
#         system "wget ${master_sites}/${distname}${extract.suffix} --no-check-certificate --progress=bar:force -O ${distpath}/${distname}${extract.suffix}"
#     }
}

########################################################################
# Projects including the 'kf5' port group can optionally set
#
#  - their project name as 'kf5.project'
#
# in that case, they should specify whether they are
#
#  - a framework by defining 'kf5.framework'
#
#  - a porting aid by defining 'kf5.portingAid'
#
#  - or a regular KF5 project which requires setting
#    + a virtual path in 'kf5.virtualPath' (e.g. "applications")
#    + as well as (optionally) a release in 'kf5.release' (e.g. "15.04.2")
#    + or (optionally) a plasma version in 'kf5.plasma' (e.g. 5.4.3)
#    + and a category for applications (kf5.category).
#
# otherwise the port will fail to build.
#
# Given the KDE release schedule with its linked versioning across all
# members of a "family" (applications, plasma, frameworks), an attempt
# is made to reduce the frequency of updates by providing "kf5.latest_*"
# variables which should never be anterior to the main version.
# Usage:
# After the regular command sequency leading up to the PortGroup include
# call kf5.use_latest kf5.release|kf5.version|kf5.plasma
# or
# call kf5.use_latest applications|frameworks|plasma .
########################################################################

if {[file exists ${kf5::currentportgroupdir}/compress_workdir-1.0.tcl] && ${kf5::includecounter} == 0} {
    PortGroup           compress_workdir 1.0
}

if { ![ info exists kf5.project ] } {
    ui_debug "kf5.project is not defined; falling back to \"manual\" configuration"
} else {
    name                kf5-${kf5.project}
}

# KF5 frameworks current version, which is the same for all frameworks
if {![info exists kf5.version]} {
    set kf5.version     5.60.0
    # kf5.latest_version is supposed to be used only in the KF5-Frameworks Portfile
    # when updating it to the new version (=kf5.latest_version). This feature is
    # activated only when a file `port dir KF5-Frameworks`/files/enable_latest exists.
    # The variable is thus no longer defined here.
    # When upgrading, don't forget that port:kf5-breeze-icons and port:kf5-oxygen-icons5
    # are part of the frameworks universe and should be kept in sync.
}
set kf5.frameworks_attic 5.69.0

# KF5 Applications version
if {![ info exists kf5.release ]} {
    set kf5.release     17.04.2
    set kf5.latest_release \
                        17.12.1
}
set kf5.release_attic   19.11.90

# KF5 Plasma version
if {![ info exists kf5.plasma ]} {
    set kf5.plasma      5.11.1
    set kf5.latest_plasma \
                        5.11.1
}
set kf5.plasma_attic    5.16.5

# the software quality. Defaults to "stable" but can be set to "unstable" before calling kf5.set_project
set kf5.quality         "stable"

platforms               darwin linux
categories              kf5 kde devel
license                 GPL-2+

set kf5.branch          [join [lrange [split ${kf5.version} .] 0 1] .]

if {${kf5::includecounter} == 0} {

    # Make sure to not use any already installed headers and libraries;
    # these are set in CPATH and LIBRARY_PATH anyway.
    configure.ldflags-delete  -L${prefix}/lib
    configure.cppflags-delete -I${prefix}/include

    if {![info exists kf5.dont_use_xz]} {
        use_xz          yes
    }

    # kf5.py* variable definitions (now kf5::py* namespaced variables) were
    # here; moved to kf5_frameworks-1.0.tcl

    platform darwin {
        if {![variant_exists nativeQSP]} {
            variant nativeQSP description {use the native Apple-style QStandardPaths locations} {}
        }

    #     if {![file exists ${qt_includes_dir}/QtCore/qextstandardpaths.h]}
        if {![catch {set result [active_variants qt5-qtbase {}]}]} {
            ui_debug "port:qt5-qtbase is installed and active"
            default_variants +nativeQSP
        }

        if {![variant_isset nativeQSP]} {
            configure.cppflags-append \
                            -DQT_USE_EXTSTANDARDPATHS -DQT_EXTSTANDARDPATHS_ALT_DEFAULT=true
            # experimental:
            configure.args-append \
                            -DAPPLE_FORCE_UNIX_DIRS=ON -DAPPLE_SUPPRESS_INSTALLDIRS_WARNING=OFF
        } else {
            # experimental:
            configure.args-append \
                            -DAPPLE_FORCE_UNIX_DIRS=OFF -DAPPLE_SUPPRESS_INSTALLDIRS_WARNING=ON
        }
    }

    # TODO:
    #
    # Phonon added as library dependency here as most, if not all KDE
    # programs current need it.  The phonon port, which includes this
    # PortGroup overrides depends_lib, removing "port:phonon" to prevent a
    # cyclic dependency
    #depends_lib-append      port:phonon

    # This is used by all KF5 frameworks
    depends_build-append    path:share/ECM/cmake/ECMConfig.cmake:kde-extra-cmake-modules
    depends_skip_archcheck-append \
                            kde-extra-cmake-modules kde-extra-cmake-modules-devel

    # configure.args-append   -G "\"CodeBlocks - Unix Makefiles\""

    # set a best-compromise plugin destination directory, the one from Qt5.
    # this is also what Kubuntu does, and possibly the only way to ensure that Qt5
    # and KF5 find each other's (and their own...) plugins.
    # The QML install location also has to be set
    configure.args-append   -DPLUGIN_INSTALL_DIR=${qt_plugins_dir} \
                            -DKDE_INSTALL_QTPLUGINDIR=${qt_plugins_dir} \
                            -DQML_INSTALL_DIR=${qt_qml_dir} \
                            -DKDE_INSTALL_MANDIR=${prefix}/share/man


    # # This is why we need destroo.violate_mtree set to "yes"
    # configure.args-append   -DCONFIG_INSTALL_DIR="/Library/Preferences" \
    #                         -DDATA_INSTALL_DIR="/Library/Application Support"
    #
    # Actually this should be used instead of DATA_INSTALL_DIR, but it doesn't work:
    #                       -DKDE_INSTALL_DATADIR_KF5="/Library/Application Support"

    # Q: What about the often used XDG dir?
    #    (Currently it gets installed into /etc/xdg just like on Linux.)

    # standard configure args
    configure.args-append   -DBUILD_doc=OFF \
                            -DBUILD_docs=OFF \
                            -DBUILD_SHARED_LIBS=ON \
                            -DCMAKE_STRIP:FILEPATH=/bin/echo
    if {${os.platform} eq "darwin"} {
        if {![info exists kf5.applications_dir]} {
            set kf5.applications_dir \
                            ${applications_dir}/KF5
        }
        set kf5.libexec_dir ${prefix}/libexec/kde5
        set kf5.pkgconfig_dir \
                            ${prefix}/lib/pkgconfig
        configure.args-append \
                            -DBUNDLE_INSTALL_DIR=${kf5.applications_dir} \
                            -DAPPLE_SUPPRESS_X11_WARNING=ON \
                            -DCMAKE_INSTALL_LIBEXECDIR=${prefix}/libexec \
                            -DKDE_INSTALL_LIBEXECDIR=${kf5.libexec_dir} \
                            -DCMAKE_MACOSX_RPATH=ON
        if {[string match *g*-mp-* ${configure.cxx}]} {
            if {![variant_exists libcxx]} {
                variant libcxx description {Experimental option to use -stdlib=libc++ with g++-mp. \
                        Requires using port:gccX?+libcxxXY.} {}
            }
            if {[variant_isset libcxx]} {
                configure.cxx_stdlib \
                                libc++
                configure.ldflags-append \
                                -stdlib=libc++
                configure.cxxflags-delete \
                                -stdlib=libstdc++
                # configure.cxxflags tries to be clever about the -stdlib= options it accepts, so we need to be smarter.
                configure.cxxflags-append \
                                \"-stdlib=libc++\"
            }
        } else {
            if {[variant_isset libcxx]} {
                ui_warn "+libcxx is supported only with g++ from port:gcc+libcxxXY!"
                pre-configure {
                    return -code error "${subport}: Illegal variant requested"
                }
            }
        }
        # 20160914: may need to set -DCMAKE_POLICY_DEFAULT_CMP0042=NEW
    } elseif {${os.platform} eq "linux"} {
        set kf5.applications_dir \
                            ${prefix}/bin
        set kf5.libexec_dir ${prefix}/lib/${build_arch}-linux-gnu/libexec
        set kf5.pkgconfig_dir \
                            ${prefix}/lib/${build_arch}-linux-gnu/pkgconfig
        cmake.install_rpath-prepend \
                            ${prefix}/lib/${build_arch}-linux-gnu
        configure.args-append \
                            -DCMAKE_PREFIX_PATH=${prefix}
    }
    if {${os.platform} ne "darwin"} {
        if {[string match *clang* ${configure.cxx}]} {
            if {![variant_exists libcxx]} {
                variant libcxx description {highly experimental option to build against libc++. \
                        Requires using clang and an independently provided libc++ installation.} {
                    configure.cxx_stdlib \
                                    libc++
                }
            }
        } elseif {[string match *g*-mp-* ${configure.cxx}]} {
            if {![variant_exists libcxx]} {
                variant libcxx description {highly experimental option to build against libc++. \
                        Requires using port:gccX?+libcxx (7 or up) and an independently provided libc++ installation.} {}
            }
            if {[variant_isset libcxx]} {
                configure.cxx_stdlib \
                                libc++
                configure.ldflags-append \
                                -stdlib=libc++
                configure.cxxflags-delete \
                                -stdlib=libstdc++
                # configure.cxxflags tries to be clever about the -stdlib= options it accepts, so we need to be smarter.
                configure.cxxflags-append \
                                \"-stdlib=libc++\"
            }
        } else {
            if {![variant_exists libcxx]} {
                variant libcxx description {Not supported. Use libc++ when building with clang or a libc++-enabled GCC port} {}
            }
            if {[variant_isset libcxx]} {
                ui_warn "+libcxx is supported only with clang or with g++ from port:gccX?+libcxxXY!"
                pre-configure {
                    return -code error "${subport}: Invalid variant requested"
                }
            }
        }

    }
    configure.args-append   -DSYSCONF_INSTALL_DIR="${prefix}/etc"
    set kf5.docs_dir        ${prefix}/share/doc/kf5

    options kf5.allow_apidocs_generation
    default kf5.allow_apidocs_generation {yes}

    if {![variant_exists chm]} {
        variant chm requires docs description {when building the API documentation, also create a .chm version} {
            depends_build-append \
                                port:chmcmd-fpc
            depends_skip_archcheck-append \
                                chmcmd-fpc
        }
        variant docs description {build and install the API documentation, for use with Qt's Assistant and KDevelop} {
            configure.args-delete \
                                -DBUILD_doc=OFF \
                                -DBUILD_docs=OFF
            if {${subport} ne "kf5-kapidox" && ${subport} ne "kf5-kapidox-devel"} {
                if {[tbool kf5.allow_apidocs_generation]} {
                    if {![info exists kf5.framework]} {
                        kf5.depends_build_frameworks \
                                kdoctools
                    }
                    if {[info exists kf5.framework]} {
                        # KF5 frameworks are more or less guaranteed to have a metainfo.yaml file
                        # which is required for newer kapidox versions. We could check for
                        # the existence of that file, but that would mean depending on both
                        # versions of the framework.
                        kf5.depends_build_frameworks \
                                kapidox
                    } else {
                        # other software will be processed by an older KApiDox version,
                        # installed under the name kf5-kgenapidox
                        kf5.depends_build_frameworks \
                                kgenapidox
                    }
                    depends_skip_archcheck-append \
                                ${kf5::kapidox_dep} ${kf5::kgenapidox_dep}
                }
            }
        }
    }
    platform darwin {
        post-destroot {
            if {![variant_isset nativeQSP] && (${supported_archs} ne "noarch")} {
                if {[file exists ${build.dir}/CMakeCache.txt] || [file exists ${build.dir}/Makefile]} {
                    ui_msg "--->  Checking ${subport} for QSP ALT mode ..."
                    if {[catch {system "fgrep 'DQT_USE_EXTSTANDARDPATHS -DQT_EXTSTANDARDPATHS_ALT_DEFAULT=true' -R ${build.dir} --include=CMake* --include=Makefile --include=*.make 2>&1"} result context]} {
                        ui_msg "QSP ALT mode  check failed: ${result}, ${context}"
                    } else {
                        ui_info "QSP ALT mode check: OK (${result})"
                    }
                } else {
                    ui_info "####  Cannot check ${subport} for QSP ALT mode (not a CMake project)."
                }
            }
        }
    }

    post-fetch {
        if {[file exists ${worksrcpath}/examples] && [file isdirectory ${worksrcpath}/examples] && ![variant_exists examples]} {
            ui_msg "This port could provide a +examples variant"
        }
    }

    post-activate {
        if {[file exists ${prefix}/bin/kbuildsycoca5]} {
            ui_msg "--->  Updating KDE's global desktop file system configuration cache ..."
            system "${prefix}/bin/kbuildsycoca5 --global"
        }
    }

    # this should hopefully be temporary: redefine the platform statement so it takes an "else" clause
    proc ifplatform {os args} {
        global os.platform os.subplatform os.arch os.major

        set len [llength $args]
        if {$len < 1} {
            return -code error "Malformed platform specification"
        }
        if {[lindex $args end-1] eq "else"} {
            set code [lindex $args end-2]
            set altcode [lindex $args end]
            set consumed 3
        } else {
            set code [lindex $args end]
            set altcode ""
            set consumed 1
        }

        foreach arg [lrange $args 0 end-$consumed]  {
            if {[regexp {(^[0-9]+$)} $arg match result]} {
                set release $result
            } elseif {[regexp {([a-zA-Z0-9]*)} $arg match result]} {
                set arch $result
            }
        }

        set match 0
        # 'os' could be a platform or an arch when it's alone
        if {$os == "other" && ${os.platform} != "darwin"} {
            set match 1
        } elseif {$len == 2 && ($os == ${os.platform} || $os == ${os.subplatform} || $os == ${os.arch})} {
            set match 1
        } elseif {($os == ${os.platform} || $os == ${os.subplatform})
                  && (![info exists release] || ${os.major} == $release)
                  && (![info exists arch] || ${os.arch} == $arch)} {
            set match 1
        }

        # Execute the code if this platform matches the platform we're on
        if {$match} {
            uplevel 1 $code
        } elseif {${altcode} ne ""} {
            ui_debug "### Executing ifplatform 'else' condition"
            uplevel 1 $altcode
        }
    }

}

### this is the part containing things that may have to be parsed more than once:

proc kf5.set_paths {} {
    upvar #0 kf5.virtualPath vp
    upvar #0 kf5.folder f
    global kf5.portingAid
    global kf5.framework
    global kf5.branch
    if { [info exists kf5.portingAid] } {
        set vp          "frameworks"
        set f           "frameworks/${kf5.branch}/portingAids"
    }

    if { [info exists kf5.framework] } {
        set vp          "frameworks"
        set f           "frameworks/${kf5.branch}"
    }
}
kf5.set_paths

proc kf5.is_framework {} {
    upvar #0 kf5.portingAid pa
    upvar #0 kf5.framework f
    unset pa
    set f yes
    kf5.set_paths
}

proc kf5.is_portingAid {} {
    upvar #0 kf5.portingAid pa
    upvar #0 kf5.framework f
    unset f
    set pa yes
    kf5.set_paths
}

namespace eval kf5 {
    set cat ""
}

## options to control git depth fetching.
options kf5.git.depth kf5.git.shallowbefore
default kf5.git.depth {}
# 20200518:
# by default we create working copies that are shallow before Jan 1st 2018
# that should include any commit we're currently requesting through git.branch .
default kf5.git.shallowbefore 2018-01-01
## set an appropriate git.url
## `kf5.git.setup project` : fetch from the KDE git server
## `kf5.git.setup host project` : fetch from ${host}${project}; "host" must be fully qualified and end with a separator
## `kf5.git.setup account project hash [prefix]` : passed through to `github.setup`
## NB: the 3rd option ignores `depth` and `shallowbefore`, so should not be used with fetch.type==git if you want
## those settings to be respected.
## NB2: the other forms set fetch.type=git .
proc kf5.git.setup {first {second ""} args} {
    global kf5.version kf5.git.depth kf5.git.shallowbefore filespath fetch.type
    if {[llength ${args}] > 0} {
        # this implies `second` isn't empty either!
        ui_debug        "Checking out through github PortGroup"
        ui_debug        "## github.setup \"${first}\" \"${second}\" \"{*}${args}\""
        github.setup    ${first} ${second} {*}${args}
    } else {
        fetch.type      git
        if {${second} eq ""} {
            set host https://invent.kde.org/kde/
            set project ${first}
        } else {
            set host    ${first}
            set project ${second}
        }
        if {[file exists ${filespath}/${project}-git/.git]} {
            ui_debug    "Cloning from local working copy"
            git.url     ${filespath}/${project}-git
        } else {
            ui_debug    "cloning \"${project}\" from host \"${host}\""
            set uri ${host}${project}
            if {${kf5.git.depth} ne {} && ${kf5.git.depth} > 0} {
                git.url -n --depth ${kf5.git.depth} ${uri}
            } elseif {${kf5.git.shallowbefore} ne {}} {
                git.url -n --shallow-since ${kf5.git.shallowbefore} ${uri}
            } else {
                git.url -n ${uri}
            }
            distname    ${project}-${kf5.version}.git
        }
    }
}

proc kf5.set_project {project} {
    upvar #0 kf5.project p
    upvar #0 kf5.folder f
    global kf5.framework
    global kf5.portingAid
    global kf5.release
    global kf5.plasma
    global kf5.virtualPath
    global kf5.category
    global kf5.version
    global kf5.quality
    global kf5.git.depth kf5.git.shallowbefore
    global fetch.type
    global filespath
    global version
    global kf5.frameworks_attic kf5.release_attic kf5.plasma_attic
    set p ${project}
    set dbranch ${kf5.quality}
    # get rid of the currently registered category:
    categories-delete       ${kf5::cat}
    if { ![info exists kf5.framework] && ![info exists kf5.portingAid] } {
        if { ![ info exists kf5.virtualPath ] } {
            ui_error "You haven't defined kf5.virtualPath, which is mandatory for any KF5 port that uses kf5.project. \
            (Or is this project perhaps a framework or porting aid?)"
            return -code error "incomplete port definition"
        } else {
            if { ![info exists kf5.release] && ![info exists kf5.plasma]} {
                ui_error "You haven't defined kf5.release or kf5.plasma, which is mandatory for any KF5 port that uses kf5.project."
                return -code error "incomplete port definition"
            } else {
                if {${kf5.virtualPath} eq "plasma"} {
                    if {[vercmp ${kf5.plasma} ${kf5.plasma_attic}] < 0} {
                        set dbranch "Attic"
                    }
                    set f   "${kf5.virtualPath}/${kf5.plasma}"
                    if {![info exists version]} {
                        version \
                            ${kf5.plasma}
                    }
                    set kf5::cat "Plasma5"
                } else {
                    if {[vercmp ${kf5.release} ${kf5.release_attic}] <= 0} {
                        set dbranch "Attic"
                        set f   "${kf5.virtualPath}/${kf5.release}/src"
                    } else {
                        set f   "release-service/${kf5.release}/src"
                    }
                    if {![info exists version]} {
                        version \
                            ${kf5.release}
                    }
                    livecheck.url \
                            https://download.kde.org/${kf5.quality}/release-service
                    livecheck.regex \
                            (\\d+\\.\\d+\\.\\d)
                    set kf5::cat "KF5-Applications"
                }
            }
        }
    } else {
        if {![info exists version]} {
            version         ${kf5.version}
        }
        if {[vercmp ${kf5.version} ${kf5.frameworks_attic}] < 0} {
            set dbranch     "Attic"
        }
    }
    categories-append       ${kf5::cat}
    distname                ${project}-${version}
    if {[info exists kf5.category]} {
        homepage            http://www.kde.org/${kf5.virtualPath}/${kf5.category}/${project}
    } else {
        homepage            http://projects.kde.org/projects/${kf5.virtualPath}/${project}
    }
    if {${fetch.type} eq "git"} {
        kf5.git.setup         ${project}
    } else {
#         See
#         https://kde.org/info/releases-19.12.1.php
#         for new/different download locations for Applications 19.12.1 (and future) releases.
        master_sites        https://download.kde.org/${dbranch}/${f}
    }
    # live dangerously ... for live-checking
    livecheck.ignore_sslcert yes
}

if {[info exists kf5.project]} {
    kf5.set_project         ${kf5.project}
}

### kf5.depends_frameworks and the framework dependency defs used to be inlined here
### include the dedicated file in which they are housed now, but only if it
### resides in the same directory as ourselves.
### Do NOT impose this restriction if we're reading a copy stored in the registry!
if {[string first "registry/portgroup" ${kf5::currentportgroupdir}] < 0} {
    if {![file exists ${kf5::currentportgroupdir}/kf5_frameworks-1.0.tcl]} {
        ui_error "The kf5 1.0 and kf5_frameworks 1.0 PortGroups should reside in the same directory"
        return -code error "KF5 PortGroup installation error"
    }
} else {
    ui_debug "Reading a registry copy of the KF5 PortGroup from ${kf5::currentportgroupdir}"
}

### more things that should or needs to be parsed only once:

if {${kf5::includecounter} == 0} {
    PortGroup kf5_frameworks 1.0
    # TODO: raise error if inclusion failed

    if {[variant_isset docs]} {
        if {${subport} ne "kf5-kapidox" && ${subport} ne "kf5-kapidox-devel"} {
            post-build {
                if {[tbool kf5.allow_apidocs_generation]} {
                    ui_msg "--->  Generating documentation for ${subport} (this can take a while)"
                    # generate the documentation, working from ${build.dir}
                    file delete -force ${workpath}/apidocs
                    xinstall -m 755 -d ${workpath}/apidocs
                    if {[variant_exists chm] && [variant_isset chm]} {
                        set chmargs "--chm --chmcompiler ${prefix}/bin/chmcmd"
                    } else {
                        set chmargs ""
                    }
                    if {[file exists ${qt_bins_dir}/qhelpgeneratorng]} {
                        set QHELPGENERATOR "${qt_bins_dir}/qhelpgeneratorng"
                    } else {
                        set QHELPGENERATOR "${qt_bins_dir}/qhelpgenerator"
                    }
                    # this appears to be necessary, sometimes:
                    system "chmod 755 ${workpath}/apidocs"
                    if {[info exists kf5.framework]} {
                        set kapidox_dir ${build.dir}/kapidox
                        file delete -force ${kapidox_dir}
                        xinstall -m 755 -d ${kapidox_dir}
                        if {[catch {system -W ${kapidox_dir} "kapidox_generate --qhp \
                            ${chmargs} \
                            --qtdoc-dir ${qt_docs_dir} --qhelpgenerator ${QHELPGENERATOR} \
                            ${worksrcpath}"} result context]} {
                            ui_warn "Failure generating documentation: ${result}"
                        }
                        # after creating the destination, copy all generated qch documentation to it
                        foreach doc [glob -nocomplain ${kapidox_dir}/frameworks/*/qch/*.qch \
                            ${kapidox_dir}/*/qch/*.qch ${kapidox_dir}/*/html/*.chm] {
                            if {[file tail ${doc}] ne "None.qch"} {
                                system "chmod 644 ${doc}"
                                xinstall -m 644 ${doc} ${workpath}/apidocs/
                            }
                        }
                        if {[file exists ${kapidox_dir}/${kf5.framework}-${version}/html/Makefile]} {
                            ui_debug "generating .docset version"
                            system -W ${kapidox_dir}/${kf5.framework}-${version}/html \
                                "make > /dev/null"
                            set docset ${kapidox_dir}/${kf5.framework}-${version}/html/org.kde.${kf5.framework}-${version}.docset
                            if {[file exists ${docset}]} {
                                file rename ${docset} ${workpath}/apidocs
                            }
                        }
                        file delete -force ${kapidox_dir}
                    } else {
                        system -W ${build.dir} "kgenapidox --qhp --searchengine --api-searchbox \
                            ${chmargs} \
                            --qtdoc-dir ${qt_docs_dir} --kdedoc-dir ${kf5.docs_dir} \
                            --qhelpgenerator ${QHELPGENERATOR} ${worksrcpath}"
                        # after creating the destination, copy all generated qch documentation to it
                        foreach doc [glob -nocomplain ${build.dir}/apidocs/qch/*.qch  ${build.dir}/apidocs/html/*.chm] {
                            if {[file tail ${doc}] ne "None.qch"} {
                                system "chmod 644 ${doc}"
                                xinstall -m 644 ${doc} ${workpath}/apidocs/
                            }
                        }
                        file delete -force ${build.dir}/apidocs
                    }
                }
            }
            post-destroot {
                if {[tbool kf5.allow_apidocs_generation]} {
                    xinstall -m 755 -d ${destroot}${kf5.docs_dir}
                    # this appears to be necessary, sometimes:
                    system "chmod 755 ${destroot}${kf5.docs_dir}"
                    foreach doc [glob -nocomplain ${workpath}/apidocs/*.qch] {
                        xinstall -m 644 ${doc} ${destroot}${kf5.docs_dir}
                        # maybe not such a useful idea:
#                         if {[info procs qt5.register_qch_files] ne ""} {
#                             qt5.register_qch_files ${kf5.docs_dir}/[file tail ${doc}]
#                         }
                    }
                    foreach doc [glob -nocomplain ${workpath}/apidocs/*.docset] {
                        file rename ${doc} ${destroot}${kf5.docs_dir}
                    }
                    if {[variant_exists chm] && [variant_isset chm]} {
                        foreach doc [glob -nocomplain ${workpath}/apidocs/*.chm] {
                            xinstall -m 644 ${doc} ${destroot}${kf5.docs_dir}
                        }
                    }
                }
            }
        }
    } else {
        # 20160325 : do this in the post-patch so patches around the targeted won't need to be
        # specific for +docs and -docs !
        post-patch {
            if {[file exists ${worksrcpath}/CMakeLists.txt]} {
                reinplace -q "/add_subdirectory.*(\[ ]*docs\[ \]*)/d" ${worksrcpath}/CMakeLists.txt
                reinplace -q "/add_subdirectory.*(\[ \]*doc\[ \]*)/d" ${worksrcpath}/CMakeLists.txt
                reinplace -q "/ADD_SUBDIRECTORY.*(\[ ]*docs\[ \]*)/d" ${worksrcpath}/CMakeLists.txt
                reinplace -q "/ADD_SUBDIRECTORY.*(\[ \]*doc\[ \]*)/d" ${worksrcpath}/CMakeLists.txt
            }
        }
    }

    proc kf5.add_test_library_path {path} {
        global os.platform
        if {${os.platform} eq "darwin"} {
            test.env DYLD_LIBRARY_PATH=${path}
        } else {
            test.env LD_LIBRARY_PATH=${path}
        }
    }

    proc kf5.use_latest {lversion} {
        global kf5.latest_release kf5.latest_version kf5.latest_plasma kf5.project kf5.set_project kf5.branch
        global version subport
        upvar #0 kf5.version v
        upvar #0 kf5.release r
        upvar #0 kf5.plasma p
        upvar #0 kf5.branch b
        switch -nocase ${lversion} {
            kf5.version     {
                ui_debug "Using kf5.version=${kf5.latest_version} instead of ${v} for ${subport}"
                set v ${kf5.latest_version}
            }
            kf5.release     {
                ui_debug "Using kf5.release=${kf5.latest_release} instead of ${r} for ${subport}"
                set r ${kf5.latest_release}
            }
            kf5.plasma      {
                ui_debug "Using kf5.plasma=${kf5.latest_plasma} instead of ${p} for ${subport}"
                set p ${kf5.latest_plasma}
            }
            frameworks      {
                ui_debug "Using kf5.version=${kf5.latest_version} instead of ${v} for ${subport}"
                set v ${kf5.latest_version}
            }
            applications    {
                ui_debug "Using kf5.release=${kf5.latest_release} instead of ${r} for ${subport}"
                set r ${kf5.latest_release}
            }
            plasma          {
                ui_debug "Using kf5.plasma=${kf5.latest_plasma} instead of ${p} for ${subport}"
                set p ${kf5.latest_plasma}
            }
            default         {
                ui_error "Illegal argument ${lversion} to kf5.use_latest"
                return -code error "Illegal argument to kf5.use_latest"
            }
        }
        # be sure that kf5.branch is set correctly too
        set b               [join [lrange [split ${v} .] 0 1] .]
        # and ditto for the paths.
        kf5.set_paths
        unset version
        if {[info exists kf5.project]} {
            kf5.set_project ${kf5.project}
        }
    }

    # provide links to icons from an installed theme in a format that is acceptable for ecm_add_app_icon
    # iconDir : the full path to the icon theme directory (no trailing slash!)
    # category : the category to which the icon belongs (ex: actions, or apps; no trailing slash!)
    # iconName : the name of the icon file (must be a .png)
    # destination: the full path to the destination directory
    # see port:kf5-kdelibs4support (post-patch) for an example on how to use this.
    proc kf5.link_icons {iconDir category iconName destination} {
        set iconlist [glob -nocomplain ${iconDir}/*/${category}/${iconName}]
        if {${iconlist} eq ""} {
            set iconlist [glob -nocomplain ${iconDir}/base/*/${category}/${iconName}]
            set iconDir ${iconDir}/base
        }
        foreach icon ${iconlist} {
            set ifile [strsed ${icon} "s|${iconDir}/||"]
            set ifile [strsed ${ifile} "s|x\[0-9\]*/${category}/|-|"]
            if {![file exists ${destination}/${ifile}]} {
                ui_info "${icon} -> ${destination}/${ifile}"
                ln -s ${icon} ${destination}/${ifile}
            }
        }
    }

    # rename icon files, for use with the kde4compat variant, in the post-destroot
    # example:
    # kf5.rename_icons ${destroot}${prefix}/share/icons/hicolor apps kate kate5
    proc kf5.rename_icons {iconDir category iconOld iconNew {destination 0}} {
        if {${destination} eq "0"} {
            set destination ${iconDir}
        }
        foreach icon [glob -nocomplain ${iconDir}/*/${category}/${iconOld}.*] {
            set ipath [strsed ${icon} "s|${iconDir}/||"]
            # get the extention (png or svg or svgz)
            set ext [strsed ${ipath} "s|.*${iconOld}\.||"]
            # remove the original icon name
            set ipath [strsed ${ipath} "s|${iconOld}\.${ext}||"]
            if {[file exists ${icon}]} {
                # remove dest. file if already present
                file delete -force ${destination}/${ipath}${iconNew}.${ext}
                file rename ${icon} ${destination}/${ipath}${iconNew}.${ext}
            }
        }
    }

    # check how the named framework is installed, +qspXDG or
    # (in some future) +nativeQSP
    # use of this procedure requires the active_variants 1.1 PortGroup!
    proc kf5.check_qspXDG {name} {
        if {![catch {set nativeQSP [active_variants "kf5-${name}" nativeQSP]}]
                && ![catch {set qspXDG [active_variants "kf5-${name}" qspXDG]}]} {
            if {${nativeQSP}} {
                ui_debug "kf5-${name} is installed +nativeQSP; check_qspXDG returns false"
                return no
            } elseif {${qspXDG}} {
                ui_debug "kf5-${name} is installed +qspQSP; check_qspXDG returns true"
                return yes
            }
        }
        return no
    }


    # create a wrapper script in ${prefix}/bin for an application bundle in kf5.applications_dir
    options kf5.wrapper_env_additions
    default kf5.wrapper_env_additions ""
    proc kf5.add_app_wrapper {wrappername {bundlename ""} {bundleexec ""}} {
        global kf5.applications_dir os.platform kf5.wrapper_env_additions destroot prefix

        qt5.wrapper_env_additions "[join ${kf5.wrapper_env_additions}]"
        if {${os.platform} eq "darwin"} {
            if {${bundlename} eq ""} {
                set bundlename ${wrappername}
            }
            if {${bundleexec} eq ""} {
                set bundleexec [file tail ${bundlename}]
            }
        } else {
            global kf5.project qt_libs_dir
            # no app bundles on this platform, but provide the same API by pretending there are.
            # If unset, use kf5.project to guess the exec. name because evidently we cannot
            # symlink ${wrappername} onto itself.
            if {${bundlename} eq ""} {
                set bundlename ${kf5.project}
            }
            if {${bundleexec} eq ""} {
                set bundleexec ${bundlename}
            }
        }
        qt5.add_app_wrapper ${wrappername} ${bundlename} ${bundleexec} ${kf5.applications_dir}
        # modify the Exec entry in the port's .desktop files
        foreach df [glob -nocomplain ${destroot}${prefix}/share/applications/*${bundlename}*.desktop] {
            reinplace -q "s|Exec=${bundlename} |Exec=${prefix}/bin/${wrappername} |g" ${df}
        }
        foreach df [glob -nocomplain ${destroot}${prefix}/share/metainfo/*.${bundlename}.appdata.xml] {
            reinplace -q "s|<binary>${bundlename}</binary>|<binary>${prefix}/bin/${wrappername}</binary>|g" ${df}
        }
    }

    # procedure to record a conflict with a KDE4 port if kde4compat isn't active. This procedure
    # creates the kde4compat variant with a boilerplate description (if it doesn't exist yet).
    # If the variant has to conflict with other variants it must be declared explicitly before
    # calling kf5.kde4compat.
    # To be used outside of any special blocks (post/pre - configure/build/destroot)
    #
    # kf5.kde4compat [-port kde4port] [\{compat code\}] [else \{KDE4 INcompatibility code\}]
    # (where square brackets enclose optional arguments
    # Note that `kde4port` can contain a list of ports enclosed in double quotes
    # (-port "a b c").
    #
    proc kf5.kde4compat {args} {
        global subport
        set len [llength ${args}]
        set kde4port ""
        set codeArg 0
        set argError no
        if {${len} >= 1} {
            if {[lindex ${args} 0] eq "-port"} {
                if {${len} >= 2} {
                    set kde4port [lindex ${args} 1]
                    set codeArg 2
                } else {
                    set argError yes
                }
            }
        }
        if {${len} >= ${codeArg}+1} {
            set code [lindex ${args} ${codeArg}]
            if {${len} > ${codeArg}+1} {
                if {[lindex ${args} ${codeArg}+1] eq "else"} {
                    set altcode [lindex ${args} ${codeArg}+2]
                } else {
                    set argError yes
                }
            }
        } elseif {${len} < ${codeArg}} {
            set argError yes
        }
        if {${argError}} {
            ui_error "kf5.kde4compat \[-port kde4port\] \[\{compat code\}\] \[else \{KDE4 INcompatibility code\}\]"
            return -code error "Malformed kf5.kde4compat invocation"
        }
        if {${kde4port} eq ""} {
            if {[string first "kf5-" ${subport}] >= 0} {
                set kde4port [string range ${subport} 4 end]
            } else {
                ui_error "kf5.kde4compat cannot determine the related KDE4 port for \"${subport}\""
                return -code error "Improper use of kf5.kde4compat"
            }
        }
        if {![variant_exists kde4compat]} {
            variant kde4compat description "Allow installation alongside KDE4's port:${kde4port}" {}
        }
        if {![variant_isset kde4compat]} {
            conflicts-append ${kde4port}
            if {[info exists altcode]} {
                ui_debug "### Executing -kde4compat code"
                uplevel 1 ${altcode}
            }
        } elseif {[info exists code]} {
            ui_debug "### Executing +kde4compat code"
            uplevel 1 ${code}
        }
    }

    proc kf5.require_kf5compat {args} {
        global subport prefix
        set len [llength ${args}]
        set kde4port ""
        set unwantedFile ""
        set argError no
        set nextArg 0
        if {${len} >= 1} {
            if {[lindex ${args} 0] eq "-port"} {
                if {${len} >= 2} {
                    set kde4port [lindex ${args} 1]
                    set nextArg 2
                } else {
                    set argError yes
                }
            }
        }
        if {${len} >= ${nextArg}+1} {
            set unwantedFile [lindex ${args} ${nextArg}]
        }
        if {${argError}} {
            ui_error "kf5.require_kf5compat \[-port kde4port\]"
            return -code error "Malformed kf5.require_kf5compat invocation"
        }
        if {${kde4port} eq ""} {
            if {[string first "kf5-" ${subport}] >= 0} {
                set kde4port [string range ${subport} 4 end]
            } else {
                ui_error "kf5.require_kf5compat cannot determine the related KDE4 port for \"${subport}\""
                return -code error "Improper use of kf5.require_kf5compat"
            }
        }
        if {${unwantedFile} eq ""} {
            if {![catch {set result [active_variants ${kde4port} kf5compat ""]}]} {
                if {!${result}} {
                    conflicts-append ${kde4port}
                } else {
                    ui_debug "${kde4port} installed with +kf5compat"
                }
            } else {
                ui_debug "${kde4port} not installed (OK)"
            }
        } else {
            if {[file exists ${prefix}/${unwantedFile}]} {
                ui_debug "Incompatible ${kde4port} installed (has ${prefix}/${unwantedFile})"
                conflicts-append ${kde4port}
            } else {
                ui_debug "${kde4port} installed with +kf5compat or not at all"
            }
        }
    }

    if {[info procs qt5.active_version] eq ""} {
        proc qt5.active_version {} {
            global prefix
            if {[file exists ${prefix}/bin/pkg-config]} {
                return [exec ${prefix}/bin/pkg-config --modversion Qt5Core]
            } else {
                return 0.0.0
            }
        }
    }

    proc kf5.depends_qt5_components {first args} {
        global qt5.using_kde
        set args [linsert $args[set list {}] 0 ${first}]
        if {![info exists qt5.using_kde] || !${qt5.using_kde}} {
            foreach comp ${args} {
                qt5.depends_component ${comp}
            }
        } else {
            foreach comp ${args} {
                switch ${comp} {
                    "qtwebkit" -
                    "qtwebengine" -
                    "qtwebview" {
                        qt5.depends_component ${comp}
                    }
                    # default is to ignore (component is part of port:qt5-kde)
                }
            }
        }
    }

    if {[variant_exists debug] && [variant_isset debug]} {
        if {[string match *clang* ${configure.cxx}] || [string match *clang* ${configure.cc}]} {
            configure.cflags-append     -fno-limit-debug-info -fstandalone-debug
            configure.cxxflags-append   -fno-limit-debug-info -fstandalone-debug
        }
    }

    # create a .macports-$subport-configure.cmd file containing the cmake invocation details
    if {![tbool kf5.no_configure_log]} {
        cmake.save_configure_cmd "install log"
    } else {
        cmake.save_configure_cmd
    }

}

set kf5::includecounter [expr ${kf5::includecounter} + 1]

# kate: backspace-indents true; indent-pasted-text true; indent-width 4; keep-extra-spaces true; remove-trailing-spaces modified; replace-tabs true; replace-tabs-save true; syntax MacPorts/Portfile; tab-indents true; tab-width 4;
