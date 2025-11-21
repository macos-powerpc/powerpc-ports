# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4
#
# Copyright (c) 2019-25 R.J.V. Bertin
# All rights reserved.
#
# Usage:
# PortGroup     LTO 1.0

namespace eval LTO {}

set LTO.must_be_disabled no

if {![info exists LTO.LTO_variant]} {
    set LTO.LTO_variant "LTO"

    if {[variant_exists ${LTO.LTO_variant}]} {
        ui_debug "LTO: the \"${LTO.LTO_variant}\" variant is already defined by the ${subport} Portfile"
        set LTO.disable_LTO 1
    } elseif {![variant_exists ${LTO.LTO_variant}]} {
        if {[tbool LTO.disable_LTO]} {
            ui_debug "${LTO.LTO_variant} cannot be activated"
            set LTO.must_be_disabled yes
            variant ${LTO.LTO_variant} description {dummy variant: link-time optimisation disabled for this port} {
                pre-configure {
                    ui_warn "The +${LTO.LTO_variant} variant has been disabled and thus has no effect"
                }
                notes-append "Port ${subport} has been installed with a dummy +${LTO.LTO_variant} variant!"
                # cast the iron while it's hot (takes care of +LTO on the commandline)
                if {[variant_isset ${LTO.LTO_variant}]} {
                     ui_warn "Variant +${LTO.LTO_variant} unsetting itself!"
                     unset ::variations(${LTO.LTO_variant})
                }
            }
            # cast the iron while it's hot (takes care of +LTO on the commandline)
            if {[variant_isset ${LTO.LTO_variant}]} {
                 ui_warn "Variant disabled, please don't request +${LTO.LTO_variant}!"
                 unset ::variations(${LTO.LTO_variant})
            }
        } else {
            variant ${LTO.LTO_variant} description {build with link-time optimisation} {}
        }
    }

} else {
    ui_debug "LTO: the \"LTO\" variant will be called \"${LTO.LTO_variant}\""
    ui_debug "     AND is ASSUMED to be provided by the Portfile!!"
    set LTO::port_provides_LTO_variant yes
    set LTO.disable_LTO 1
}

options LTO.supports_i386 \
        LTO.gcc_lto_jobs
default LTO.supports_i386 yes
if {![string match *make ${build.cmd}]} {
    # "make" has an internal job server that can be used to control the number of
    # concurrent LTO jobs spawned by each GCC link command, but other build commands
    # (like Ninja) don't. It is thus best to let GCC spawn only a single LTO subprocess
    # rather than having N link commands spawning N such processes.
    default LTO.gcc_lto_jobs 1
} elseif {[string match *clang* ${configure.compiler}]} {
    default LTO.gcc_lto_jobs {${build.jobs}}
} else {
    default LTO.gcc_lto_jobs "auto"
}

if {![info exists LTO_needs_ranlib]} {
    set LTO_needs_ranlib no
}

proc LTO::variant_enabled {v} {
    global LTO.disable_LTO LTO.LTO_variant
    if {${v} eq "${LTO.LTO_variant}" && [tbool LTO.disable_LTO]} {
        ui_debug "The LTO PG variant ${LTO.LTO_variant} is force-disabled because of LTO.disable_LTO=${LTO.disable_LTO}"
        return 0
    } else {
        ui_debug "\[variant_isset ${v}\]=[variant_isset ${v}]"
        return [variant_isset ${v}]
    }
}

if {[string match "macports-clang*" ${configure.compiler}]} {
    set LTO::mp_compiler_version [string map {"macports-clang-" ""} ${configure.compiler}]
} elseif {[string match "macports-gcc*" ${configure.compiler}]} {
    set LTO::mp_compiler_version [string map {"macports-gcc-" ""} ${configure.compiler}]
} else {
    set LTO::mp_compiler_version -1
}

# Set up AR, NM and RANLIB to prepare for +LTO even if we don't end up using it
options configure.ar \
        configure.nm \
        configure.ranlib \
        LTO.use_archive_helpers \
        LTO.cpuflags \
        LTO.compatcpu \
        LTO.ltoflags

# give the port a say over whether or not the selected helpers are used
default LTO.use_archive_helpers yes
default LTO.cpuflags {}
default LTO.compatcpu westmere
default LTO.compatflags {-msse4.1 -msse4.2 -msse3 -mssse3 -msse2 -msse -mmmx -mpclmul}
default LTO.ltoflags {}

if {![info exists LTO.allow_ThinLTO]} {
    set LTO.allow_ThinLTO yes
}

if {![info exists LTO.allow_UseLLD]} {
    set LTO.allow_UseLLD yes
}
# allow to force -fuse_ld=ld with clang
if {![info exists LTO.maybe_ForceLD]} {
    set LTO.maybe_ForceLD yes
}

## NB: clang also supports -ffat-lto-objects from v17 and up
if {![info exists LTO.fat_LTO_Objects]} {
    set LTO.fat_LTO_Objects no
}

# NB
# FIXME
# We should ascertain that configure.{ar,nm,ranlib} be full, absolute paths!
# NB

if {${os.platform} eq "darwin"} {
    # the Mac linker will complain without explicit LTO cache directory
    # only applies to lto=thin mode but won't hurt with lto=full.
    #
    # For ports with use_configure=no, Portfiles need to call the function
    # in an appropriate location where compiler and build.dir are set
    # and before they inject ${configure.ldflags} where and how that's required.
    proc LTO.set_lto_cache {} {
        global configure.compiler configure.ldflags build.dir
        global muniversal.current_arch merger_configure_ldflags merger_arch_flag
        if {[LTO::variant_enabled ${LTO.LTO_variant}] && ${configure.compiler} ne "clang"} {
            xinstall -m 755 -d ${build.dir}/.lto_cache
            ui_debug "Setting ${LTO.LTO_variant} cache path to ${build.dir}/.lto_cache"
            if {[info exists muniversal.build_arch] && [variant_isset universal]} {
                configure.ldflags.${muniversal.current_arch}-append -Wl,-cache_path_lto,${build.dir}/.lto_cache
            } elseif {[info exists merger_arch_flag] && [variant_isset universal]} {
                lappend merger_configure_ldflags(${muniversal.current_arch}) -Wl,-cache_path_lto,${build.dir}/.lto_cache
            } else {
                configure.ldflags-append -Wl,-cache_path_lto,${build.dir}/.lto_cache
            }
        }
    }
    post-destroot {
        if {[LTO::variant_enabled ${LTO.LTO_variant}] && ${configure.compiler} ne "clang"} {
            file delete -force ${build.dir}/.lto_cache
            set morecrud [glob -nocomplain -directory ${workpath}/.tmp/ thinlto-* cc-*.o lto-llvm-*.o]
            if {${morecrud} ne {}} {
                file delete -force {*}${morecrud}
            }
        }
    }
} else {
    post-destroot {
        if {[LTO::variant_enabled ${LTO.LTO_variant}]} {
            set morecrud [glob -nocomplain -directory ${workpath}/.tmp/ thinlto-* cc-*.o lto-llvm-*.o]
            if {${morecrud} ne {}} {
                file delete -force {*}${morecrud}
            }
        }
    }
}

# append the arguments in ${flags} to the option variable(s) in ${vars}
# LTO.flags_append configure.cflags "a b c"
# LTO.flags_append {configure.cflags configure.cxxflags} "a b c"
proc LTO.flags_append {vars flags} {
    foreach v ${vars} {
        foreach f ${flags} {
            ${v}-append ${f}
        }
    }
}

# custom version for configure.*flags option vars
proc LTO.configure.flags_append {vars flags} {
    foreach v ${vars} {
        foreach f ${flags} {
            configure.${v}-append ${f}
        }
    }
}

# out-of-line implementation so changes are made *now*.
# Qt5 has its own mechanism to set LTO flags so don't do anything
# if we end up being loaded for a build of Qt5 itself.
if {[variant_isset ${LTO.LTO_variant}] && ![info exists building_qt5]} {
    # some projects have their own configure option for LTO (often --enable-lto);
    # use this if the port tells us to
    if {[info exists LTO.configure_option]} {
        if {[LTO::variant_enabled ${LTO.LTO_variant}]} {
            ui_debug "LTO: setting custom configure option(s) \"${LTO.configure_option}\""
            configure.args-append       ${LTO.configure_option}
        } else {
            ui_warn "LTO PG: LTO.configure_option is set but so is LTO.disable_LTO - seems fishy!"
        }
    } else {
        if {[string match *clang* ${configure.compiler}]} {
            # detect support for flto=thin but only with MacPorts clang versions (being a bit cheap here)
            set clang_version [string map {"macports-clang-" ""} ${configure.compiler}]
            if {[tbool LTO.allow_ThinLTO] && "${clang_version}" ne "${configure.compiler}" && [vercmp ${clang_version} "4.0"] >= 0} {
                # the compiler supports "ThinLTO", use it if allowed
                set lto_flags           "-flto=thin"
            } else {
                set lto_flags           "-flto"
            }
            if {[tbool LTO.fat_LTO_Objects]} {
                if {${LTO::mp_compiler_version} >= 17} {
                    set lto_flags       "${lto_flags} -ffat-lto-objects"
                } elseif {[tbool LTO.require_fat_LTO_Objects]} {
                    ui_error "Port ${subport} requires fat LTO objects which are only supported by clang 17 and up"
                    return -code error "compiler doesn't support fat LTO objects"
                }
            }
        } else {
            if {${LTO.gcc_lto_jobs} ne ""} {
                set LTO::gcc_lto_jobs "=${LTO.gcc_lto_jobs}"
            } else {
                set LTO::gcc_lto_jobs   "auto"
            }
            if {${os.platform} eq "linux"} {
                set lto_flags           "-ftracer -flto${LTO::gcc_lto_jobs} -fuse-linker-plugin"
            } elseif {${configure.compiler} ne "cc"} {
                set lto_flags           "-ftracer -flto${LTO::gcc_lto_jobs}"
            }
            if {[tbool LTO.fat_LTO_Objects]} {
                set lto_flags           "${lto_flags} -ffat-lto-objects"
            }
        }
        # let's see if we can make do with only objc_lto_flags and don't need objcxx_lto_flags as well;
        # assume that projects use either ObjC or ObjC++
        if {${configure.objc} eq ${configure.cc} || ${configure.objcxx} eq ${configure.cxx}} {
            set objc_lto_flags          ${lto_flags}
        } else {
            set objc_lto_flags          ""
        }
        ui_debug "LTO: setting LTO compiler and linker option(s) \"${lto_flags}\""
        ui_debug "     ObjC and ObjC++ will use:                 \"${objc_lto_flags}\""
        pre-configure {
            if {${objc_lto_flags} eq ""} {
                ui_warn "Warning: ObjC/++ files will be compiled without LTO because of the main compiler choice!"
            }
        }
        if {[LTO::variant_enabled ${LTO.LTO_variant}]} {
            # here is the actual venom: insert the LTO flags where they should go!
            if {![variant_isset universal] || [tbool LTO.supports_i386]} {
                # consolidate the current (possibly) default values for ObjC compiler flags
                # (to make sure they're "unlinked from" the corresponding C/C++ flags!)
                configure.objcflags             {*}${configure.objcflags}
                configure.objcxxflags           {*}${configure.objcxxflags}
                # now we can add the possibly GCC-specific LTO flags into the C/C++ flags
                # without risk that they also get appended to the ObjC/++ flags.
                LTO.configure.flags_append      {cflags \
                                                cxxflags} \
                                                ${lto_flags}
                # ObjC may require different LTO flags because on Darwin we may be using clang instead of gcc.
                LTO.configure.flags_append      {objcflags \
                                                objcxxflags} \
                                                ${objc_lto_flags}
                # ${configure.optflags} is a list, and that can lead to strange effects
                # in certain situations if we don't treat it as such here.
                LTO.configure.flags_append      ldflags "${configure.optflags} ${lto_flags}"
            } else { # checking build_arch probably won't do what I thought here #  if {${build_arch} ne "i386"}
                if {[info exists merger_configure_cflags(x86_64)]} {
                    set merger_configure_cflags(x86_64) "{*}$merger_configure_cflags(x86_64) ${lto_flags}"
                } else {
                    set merger_configure_cflags(x86_64) "${lto_flags}"
                }
                if {[info exists merger_configure_cxxflags(x86_64)]} {
                    set merger_configure_cxxflags(x86_64) "{*}$merger_configure_cxxflags(x86_64) ${lto_flags}"
                } else {
                    set merger_configure_cxxflags(x86_64) "${lto_flags}"
                }
                if {[info exists merger_configure_objcflags(x86_64)]} {
                    set merger_configure_objcflags(x86_64) "{*}$merger_configure_objcflags(x86_64) ${objc_lto_flags}"
                } else {
                    set merger_configure_objcflags(x86_64) "${objc_lto_flags}"
                }
                if {[info exists merger_configure_ldflags(x86_64)]} {
                    set merger_configure_ldflags(x86_64) "{*}$merger_configure_ldflags(x86_64) ${objc_lto_flags}"
                } else {
                    set merger_configure_ldflags(x86_64) "${objc_lto_flags}"
                }
                # ${configure.optflags} is a list, and that can lead to strange effects
                # in certain situations if we don't treat it as such here.
                foreach opt ${configure.optflags} {
                    configure.ldflags-append    ${opt}
                }
                set merger_arch_flag            yes
            }
        } else {
            ui_debug "Only exporting LTO.ltoflags=${lto_flags} !"
        }
        if {${os.platform} eq "darwin" && ![tbool LTO.allow_ThinLTO]} {
            if {![variant_isset universal] || [tbool LTO.supports_i386]} {
                pre-configure {
                    LTO.set_lto_cache
                }
                if {[info exists LTO_needs_pre_build]} {
                    pre-build {
                        LTO.set_lto_cache
                    }
                }
            }
        }
        LTO.ltoflags {*}${lto_flags}
    }
}

if {[string match *clang* ${configure.compiler}]} {
    if {${os.platform} ne "darwin" || [string match macports-clang* ${configure.compiler}]} {
        # only MacPorts provides llvm-ar and family on Mac
        if {![variant_isset universal] || [info exists universal_archs_supported]} {
            default configure.ar "[string map {"clang" "llvm-ar"} ${configure.cc}]"
            default configure.nm "[string map {"clang" "llvm-nm"} ${configure.cc}]"
            if {[tbool LTO_needs_ranlib]} {
                default configure.ranlib "[string map {"clang" "llvm-ranlib"} ${configure.cc}]"
            } else {
                # ranlib is done by llvm-ar
                default configure.ranlib "/bin/echo"
            }
            set LTO.custom_binaries 1
        }
    }
    if {${os.platform} ne "darwin" \
            && [string match macports-clang* ${configure.compiler}]
            && [LTO::variant_enabled ${LTO.LTO_variant}]} {
        ## clang on ~Darwin doesn't like -Os -flto so remove that flag from the initial C*FLAGS
        ui_warn "Changing -Os for -O2 because of +${LTO.LTO_variant}"
        configure.cflags-replace -Os -O2
        configure.objcflags-replace -Os -O2
        configure.cxxflags-replace -Os -O2
        configure.objcxxflags-replace -Os -O2
        configure.ldflags-replace -Os -O2
    }
} elseif {[string match macports-gcc* ${configure.compiler}]} {
    if {![variant_isset universal] || [info exists universal_archs_supported]} {
        default configure.ar "[string map {"gcc" "gcc-ar"} ${configure.cc}]"
        default configure.nm "[string map {"gcc" "gcc-nm"} ${configure.cc}]"
        if {[tbool LTO_needs_ranlib]} {
            default configure.ranlib "[string map {"gcc" "gcc-ranlib"} ${configure.cc}]"
        } else {
            # done by gcc-ar
            default configure.ranlib "/bin/echo"
        }
        set LTO.custom_binaries 1
    }
} elseif {${os.platform} eq "linux"} {
    if {${configure.compiler} eq "cc"} {
        if {[auto_execok gcc-ar] ne ""} {
            default configure.ar "[string map {"cc" "gcc-ar"} ${configure.cc}]"
        } else {
            default configure.ar "ar"
        }
        if {[auto_execok gcc-nm] ne ""} {
            default configure.nm "[string map {"cc" "gcc-nm"} ${configure.cc}]"
        } else {
            default configure.nm "nm"
        }
        if {[auto_execok gcc-ranlib] ne ""} {
            default configure.ranlib "[string map {"cc" "gcc-ranlib"} ${configure.cc}]"
        } else {
            default configure.ranlib "ranlib"
        }
        set LTO.custom_binaries 1
    } elseif {${configure.compiler} eq "gcc"} {
        if {[auto_execok gcc-ar] ne ""} {
            default configure.ar "[string map {"gcc" "gcc-ar"} ${configure.cc}]"
        } else {
            default configure.ar "ar"
        }
        if {[auto_execok gcc-nm] ne ""} {
            default configure.nm "[string map {"gcc" "gcc-nm"} ${configure.cc}]"
        } else {
            default configure.nm "nm"
        }
        if {[auto_execok gcc-ranlib] ne ""} {
            default configure.ranlib "[string map {"gcc" "gcc-ranlib"} ${configure.cc}]"
        } else {
            default configure.ranlib "ranlib"
        }
        set LTO.custom_binaries 1
    } else {
        default configure.ar "[string map {"gcc" "gcc-ar"} ${configure.cc}]"
        default configure.nm "[string map {"gcc" "gcc-nm"} ${configure.cc}]"
        if {[tbool LTO_needs_ranlib]} {
            default configure.ranlib "[string map {"gcc" "gcc-ranlib"} ${configure.cc}]"
        } else {
            # done by gcc-ar
            default configure.ranlib "/bin/echo"
        }
        set LTO.custom_binaries 1
    }
}
if {[info exists LTO.custom_binaries]} {
    pre-configure {
        if {[option LTO.use_archive_helpers]} {
            configure.env-append \
                "AR=${configure.ar}" \
                "NM=${configure.nm}" \
                "RANLIB=${configure.ranlib}"
        }
    }
    pre-build {
        if {[option LTO.use_archive_helpers]} {
            build.env-append \
                "AR=${configure.ar}" \
                "NM=${configure.nm}" \
                "RANLIB=${configure.ranlib}"
        }
    }
} else {
    # check if port:cctools is installed; if so, use its ar/nm/ranlib.
    # We could add a depends_build on port:cctools, but these commands will
    # be picked up from the path anyway, so accept this opportunistic
    # build dependency.
    if {[file exists ${prefix}/bin/ar]} {
        default configure.ar "/opt/local/bin/ar"
        default configure.nm "/opt/local/bin/nm"
        default configure.ranlib "/opt/local/bin/ranlib"
    } else {
        default configure.ar "/usr/bin/ar"
        default configure.nm "/usr/bin/nm"
        default configure.ranlib "/usr/bin/ranlib"
    }
}

if {![variant_exists cputuned]} {
    variant cputuned conflicts cpucompat description {Build using -march=native for optimal tuning to your CPU} {}
    variant cpucompat conflicts cputuned description {Build using some commonly supported SIMD settings for optimal cross-CPU tuning} {}
}

if {[variant_isset cputuned]} {
    if {${build_arch} in [list ppc ppc64]} {
        default LTO.cpuflags "-mtune=native"
    } else {
        default LTO.cpuflags "-march=native"
    }
    default configure.march {native}
}
if {[variant_isset cpucompat]} {
    default LTO.cpuflags "-march=${LTO.compatcpu} [join ${LTO.compatflags} " "]"
    default configure.march {[option LTO.compatcpu]}
}
pre-configure {
    if {[variant_isset cputuned] || [variant_isset cpucompat]} {
        ui_debug "LTO/pre-configure: Appending CPU flags to compiler/linker flags: \"${LTO.cpuflags}\""
        LTO.configure.flags_append  {cflags \
                                    cxxflags \
                                    objcflags \
                                    objcxxflags \
                                    ldflags} \
                                    ${LTO.cpuflags}
    }
}

if {[info exists LTO_needs_pre_build]} {
    pre-build {
        if {[variant_isset cputuned] || [variant_isset cpucompat]} {
            # use [string match] on configure.cflags to see if someone already injected the cpuflags,
            # assuming it/they did it to all. The most likely candidate is the pre-configure block
            # above, which ALSO GETS EXECUTED if `use_configure == off`! Of course that will only
            # have happened if the configure and build stages are executed with a single `port` call.
            if {![string match *${LTO.cpuflags}* ${configure.cflags}]} {
                ui_debug "LTO/pre-build: Appending CPU flags to compiler/linker flags: \"${LTO.cpuflags}\""
                LTO.configure.flags_append \
                                    {cflags \
                                    cxxflags \
                                    objcflags \
                                    objcxxflags \
                                    ldflags} \
                                    ${LTO.cpuflags}
            }
        }
        build.env-append            "CFLAGS=${configure.cflags}" \
                                    "CXXFLAGS=${configure.cxxflags}" \
                                    "OBJCFLAGS=${configure.objcflags}" \
                                    "OBJCXXFLAGS=${configure.objcxxflags}" \
                                    "LDFLAGS=${configure.ldflags}"
    }
}

if {[tbool LTO.allow_UseLLD] && ![variant_exists use_lld]} {
    if {${os.platform} eq "darwin"} {
        variant use_lld conflicts universal description {use the LLD linker (not for 32bit building)} {}
    } else {
        variant use_lld description {use the LLD linker} {}
    }
    if {[variant_isset use_lld]} {
        # NB: the below assumes that $LLD is always installed by
        # the latest port:lld-XY which provides the lld linker
        # for every "MacStropified" port:clang-XY!
        if {${os.platform} eq "darwin"} {
            depends_build-append path:bin/ld64.lld:lld-17
            set LLD "${prefix}/bin/ld64.lld"
        } else {
            depends_build-append path:bin/ld.lld:lld-17
            set LLD "${prefix}/bin/ld.lld"
        }
        if {[string match "macports-clang*" ${configure.compiler}]} {
            # TODO: figure out when --ld-path= was introduced ...
            if {${LTO::mp_compiler_version} >= 15} {
                LTO.configure.flags_append {ldflags} "-fuse-ld=lld --ld-path=${LLD}"
            } else {
                LTO.configure.flags_append {ldflags} "-fuse-ld=${LLD}"
            }
        } else {
            pre-configure {
                ui_warn "+use_lld : the -fuse-ld may or may not be supported!"
                LTO.configure.flags_append {ldflags} "-fuse-ld=lld"
            }
        }
    }
}
if {![variant_exists use_lld] || ![variant_isset use_lld]} {
    if {(![tbool LTO.allow_UseLLD] || [tbool LTO.LTO.maybe_ForceLD]) && [string match "macports-clang*" ${configure.compiler}]} {
        if {${LTO::mp_compiler_version} >= 5} {
            # simple, unconditional "don't use lld" for clang compilers built to use lld by default
            LTO.configure.flags_append {ldflags} "-fuse-ld=ld"
        }
    }
}

if {![variant_exists builtwith]} {
    variant builtwith description {Label the install with the compiler used. Do not use!} {}
    if {[variant_isset builtwith]} {
        set LTO::load_compvars yes
        PortGroup compiler-variants 1.0
        unset LTO::load_compvars
    }
}
if {[variant_isset builtwith]} {
    set usedCompiler [string map {"-" "_"} [file tail ${configure.cc}]]
    if {![variant_exists ${usedCompiler}]} {
        variant ${usedCompiler} requires builtwith description "automatic placeholder variant to record the compiler used" {
            pre-configure {
                ui_warn "+builtwith+${usedCompiler} are just placeholder variants used only to label the install with the compiler used"
            }
            notes-append "+${usedCompiler} is an automatic variant which will probably require to use -nf with `port activate` to avoid side-effects!"
        }
    }
    default_variants-append +${usedCompiler}
}

proc LTO::callback {} {
    # this callback could really also handle the disable and allow switches!
    global prefix supported_archs LTO.must_be_disabled LTO.gcc_lto_jobs build.cmd configure.cmd LTO.LTO_variant

    if {[variant_exists use_lld] && [variant_isset use_lld]} {
        # lld doesn't support 32bit architectures
        supported_archs-delete i386 ppc
    }
    # don't allow the Portfile to activate the LTO variant
    if {[tbool LTO.must_be_disabled] && [variant_exists ${LTO.LTO_variant}] && [variant_isset ${LTO.LTO_variant}]} {
        ui_warn "Unsetting +${LTO.LTO_variant}!"
        unset ::variations(${LTO.LTO_variant})
    } elseif {[variant_isset ${LTO.LTO_variant}] && ${LTO.gcc_lto_jobs} eq "auto" && [string match *make ${build.cmd}]} {
        ui_debug "LTO PG setting build.cmd=gmake!"
        build.cmd           gmake
        depends_build-delete \
                            port:gmake
        depends_build-append \
                            port:gmake
    }

    if {[variant_isset use_lld]} {
        set ::env(LLVM_SYMBOLIZER_PATH) \
                            ${prefix}/libexec/lld-17/bin/llvm-symbolizer
    } elseif {[string match macports-clang* [option configure.compiler]]} {
        set ::env(LLVM_SYMBOLIZER_PATH) \
                            [string map {"clang" "llvm-symbolizer"} [option configure.cc]]
    }
}
port::register_callback LTO::callback
