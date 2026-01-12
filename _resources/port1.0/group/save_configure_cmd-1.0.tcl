# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4

namespace eval configure {
    variable redirect_configure_output no
    variable statevar no
    variable statevar2 no
    variable docdir
    proc logfile {} {
        if {[catch {set fn [get_logfile]} err]} {
            ui_debug "get_logfile not defined or returns empty string: $err"
            return ""
        } else {
            return $fn
        }
    }

    proc initialise_save_logic {save_log_too} {
        if {${save_log_too} ne ""} {
            if {[variant_isset universal] &&
                ([info exists merger_combine] || [info exists merger_arch_flag])
            } {
                # we're using one of the muniversal PortGroups; don't redefine configure.cmd!
                set no_configure_redirection yes
            }
            pre-configure {
                foreach cfile [glob -nocomplain ${workpath}/.macports.${subport}.configure*.log] {
                    # clean lingering files
                    file delete -force ${cfile}
                }
                if {(${configure::redirect_configure_output} || [configure::logfile] eq "") && ![info exists no_configure_redirection]} {
                    configure.pre_args-prepend "-o pipefail -c '${configure.cmd} "
                    if {[info exists muniversal.current_arch]} {
                        configure.post_args-append "|& tee ${workpath}/.macports.${subport}.configure-${muniversal.current_arch}.log'"
                    } else {
                        configure.post_args-append "|& tee ${workpath}/.macports.${subport}.configure.log'"
                    }
                    configure.cmd "bash"
                    ui_debug "configure command set to `${configure.cmd} ${configure.pre_args} ${configure.args} ${configure.post_args}`"
                }
            }
            if {${save_log_too} eq "install log"} {
                post-destroot {
                    set configure::docdir ${destroot}${prefix}/share/doc/${subport}
                    xinstall -m 755 -d ${configure::docdir}
                    foreach cfile [glob -nocomplain ${workpath}/.macports.${subport}.configure*] {
                        if {[file size ${cfile}] > 0} {
                            xinstall -m 644 ${cfile} ${configure::docdir}/[string map {".macports" "macports"} [file tail ${cfile}]]
                        }
                    }
                }
            }
        }
    }

    # try to guess the actual compiler command from a command string
    proc guess_compiler {cmd} {
        global prefix configure.ccache configure.distcc
        set nolauncher [string map \
                    [list "${prefix}/bin/ccache " "" \
                        "${prefix}/bin/sccache " "" \
                        "ccache " "" \
                        "sccache " "" \
                        "${prefix}/bin/distcc " "" \
                        "distcc " ""] \
                    ${cmd}]
        set compiler [lindex [split ${nolauncher} " "] 0]
        if {[file executable ${compiler}]} {
            return ${compiler}
        } else {
            ui_debug "guess_compiler failed on \"${cmd}\" (${compiler})"
            return ${cmd}
        }
    }

    proc write_configure_cmd {fname} {
        global configure.env prefix
        if {![catch {set fd [open "${fname}" "w"]} err]} {
            foreach var [array names ::env] {
                puts ${fd} "${var}=$::env(${var})"
            }
            if {[info exists configure.env]} {
                puts ${fd} "## configure.env:"
                foreach assignment [set configure.env] {
                    puts ${fd} "${assignment}"
                }
            }
            # the following variables are no longer set in the environment at this point:
            puts ${fd} "CPP=\"[option configure.cpp]\""
            # these are particularly relevant because referenced in the configure.pre_args:
            puts ${fd} "CC=\"[option configure.cc]\""
            puts ${fd} "CXX=\"[option configure.cxx]\""
            if {[option configure.objcxx] ne [option configure.cxx]} {
                puts ${fd} "OBJCXX=\"[option configure.objcxx]\""
            }
            puts ${fd} "CPPFLAGS=\"[option configure.cppflags]\""
            puts ${fd} "CFLAGS=\"[option configure.cflags]\""
            puts ${fd} "CXXFLAGS=\"[option configure.cxxflags]\""
            if {[option configure.objcflags] ne [option configure.cflags]} {
                puts ${fd} "OBJCFLAGS=\"[option configure.objcflags]\""
            }
            if {[option configure.objcxxflags] ne [option configure.cxxflags]} {
                puts ${fd} "OBJCXXFLAGS=\"[option configure.objcxxflags]\""
            }
            puts ${fd} "LDFLAGS=\"[option configure.ldflags]\""
            set CXX [guess_compiler [option configure.cxx]]
            set OBJCXX [guess_compiler [option configure.objcxx]]
            if {[string match ${prefix}* ${CXX}] \
                    || [string match ${prefix}* ${OBJCXX}]} {
                set port [registry_file_registered ${CXX}]
                if {${port} != 0} {
                    puts ${fd} "#    C++ compiler provided by: [lrange [lindex [registry_active ${port}] 0] 0 3]"
                }
                if {"${OBJCXX}" ne "${CXX}"} {
                    set port [registry_file_registered ${OBJCXX}]
                    if {${port} != 0} {
                        puts ${fd} "# ObjC++ compiler provided by: [lrange [lindex [registry_active ${port}] 0] 0 3]"
                    }
                }
            }
            puts ${fd} "\n# Commandline configure options:"
            if {[option configure.optflags] ne ""} {
                puts -nonewline ${fd} " configure.optflags=\"[option configure.optflags]\""
            }
            if {[option configure.compiler] ne ""} {
                puts -nonewline ${fd} " configure.compiler=\"[option configure.compiler]\""
            }
            set OBJC [guess_compiler [option configure.objc]]
            if {${OBJC} ne "[guess_compiler [option configure.cc]]"} {
                puts -nonewline ${fd} " configure.objc=\"${OBJC}\""
            }
            if {"${OBJCXX}" ne "${CXX}"} {
                puts -nonewline ${fd} " configure.objcxx=\"${OBJCXX}\""
            }
            if {[option configureccache] ne ""} {
                puts -nonewline ${fd} " configureccache=\"[option configureccache]\""
            }
            if {[option configure.cxx_stdlib] ne ""} {
                puts -nonewline ${fd} " configure.cxx_stdlib=\"[option configure.cxx_stdlib]\""
            }
            puts ${fd} ""
            puts ${fd} "\ncd [option configure.dir]"
            puts ${fd} "[option configure.cmd] [join [option configure.pre_args]] [join [option configure.args]] [join [option configure.post_args]]"
            close ${fd}
            unset fd
        }
    }

    proc try_copy_configure_log {fname} {
        variable redirect_configure_output
        set logfile [logfile]
        if {!${redirect_configure_output} && ${logfile} ne ""} {
            ui_debug "[dict get [info frame 0] proc]: Filtering configure log from ${logfile})"
            if {![catch {flush_logfile} err]} {
                ui_debug "Flushed file ${logfile}"
            } else {
                ui_debug "Couldn't flush ${logfile}: $err"
            }
            exec sync
            catch {exec egrep ":info:configure |:notice:configure |:msg:configure " ${logfile} | \
                sed "s/:\[^:\]*:configure //g" > ${fname}}
        }
    }

}

# From: https://wiki.tcl-lang.org/page/proc+alias
proc configure.alias {alias target} {
    set fulltarget [uplevel [list namespace which $target]]
    if {$fulltarget eq {}} {
        return -code error "configure::alias \"${target}\" for \"${alias}\": no such command"
    }
    set save [namespace eval [namespace qualifiers $fulltarget] {
        namespace export}]
    namespace eval [namespace qualifiers $fulltarget] {namespace export *}
    while {[namespace exists [
        set tmpns [namespace current]::[info cmdcount]]]} {}
    set code [catch {set newcmd [namespace eval $tmpns [
        string map [list @{fulltarget} [list $fulltarget]] {
        namespace import @{fulltarget}
    }]]} cres copts]
    namespace eval [namespace qualifiers $fulltarget] [
        list namespace export {*}$save]
    if {$code} {
        return -options $copts $cres
    }
    uplevel [list rename ${tmpns}::[namespace tail $target] $alias]
    namespace delete $tmpns 
    return [uplevel [list namespace which $alias]]
}

# proc configure.test {args} {
# 	ui_msg "[dict get [info frame 0] proc]: ${args}"
# }

proc configure.save_configure_cmd {{save_log_too ""}} {
    namespace upvar ::configure configure_cmd_saved statevar
    if {${configure::statevar}} {
        ui_warn "[dict get [info frame 0] proc] already called"
        return;
    }
    set configure::statevar yes

    if {![info exists configure.args]} {
        configure.args-append
    }
    if {![info exists configure.post_args]} {
        configure.post_args-append
    }
    configure::initialise_save_logic "${save_log_too}"
    post-configure {
        configure::write_configure_cmd "${workpath}/.macports.${subport}.configure.cmd"
        configure::try_copy_configure_log "${workpath}/.macports.${subport}.configure.log"
    }
}

proc configure.save_build_cmd {{save ""}} {
    namespace upvar ::configure configure_cmd_saved statevar2
    global build.env prefix
    if {${configure::statevar2}} {
        ui_debug "configure.save_build_cmd already called"
        return;
    }
    set configure::statevar2 yes

    if {![info exists build.args]} {
        build.args-append
    }
    if {![info exists build.post_args]} {
        build.post_args-append
    }
    if {${save} eq "install"} {
        post-destroot {
            set configure::docdir ${destroot}${prefix}/share/doc/${subport}
            xinstall -m 755 -d ${configure::docdir}
            foreach cfile [glob -nocomplain ${workpath}/.macports.${subport}.build*] {
                if {[file size ${cfile}] > 0} {
                    xinstall -m 644 ${cfile} ${configure::docdir}/[string map {".macports" "macports"} [file tail ${cfile}]]
                }
            }
        }
    }
    pre-build {
        if {![catch {set fd [open "${workpath}/.macports.${subport}.build.cmd" "w"]} err]} {
            puts ${fd} "## Executing: ##"
            foreach var [array names ::env] {
                puts ${fd} "${var}=$::env(${var})"
            }
            if {[info exists build.env]} {
                puts ${fd} "## build.env:"
                foreach assignment [set build.env] {
                    puts ${fd} "${assignment}"
                }
            }
            puts ${fd} "\ncd ${build.dir}"
            puts ${fd} "${build.cmd} [join ${build.pre_args}] [join ${build.args}] [join ${build.post_args}]"
            close ${fd}
            unset fd
        }
    }
    post-build {
        # rewrite the file after successful build completion
        if {![catch {set fd [open "${workpath}/.macports.${subport}.build.cmd" "w"]} err]} {
            foreach var [array names ::env] {
                puts ${fd} "${var}=$::env(${var})"
            }
            if {[info exists build.env]} {
                puts ${fd} "## build.env:"
                foreach assignment [set build.env] {
                    puts ${fd} "${assignment}"
                }
            }
            # the following variables are no longer set in the environment at this point:
            puts ${fd} "CPP=\"${configure.cpp}\""
            # these are particularly relevant because referenced in the configure.pre_args:
            puts ${fd} "CC=\"${configure.cc}\""
            puts ${fd} "CXX=\"${configure.cxx}\""
            if {${configure.objcxx} ne ${configure.cxx}} {
                puts ${fd} "OBJCXX=\"${configure.objcxx}\""
            }
            puts ${fd} "CFLAGS=\"${configure.cflags}\""
            puts ${fd} "CXXFLAGS=\"${configure.cxxflags}\""
            if {${configure.objcflags} ne ${configure.cflags}} {
                puts ${fd} "OBJCFLAGS=\"${configure.objcflags}\""
            }
            if {${configure.objcxxflags} ne ${configure.cxxflags}} {
                puts ${fd} "OBJCXXFLAGS=\"${configure.objcxxflags}\""
            }
            puts ${fd} "LDFLAGS=\"${configure.ldflags}\""
            if {[string match ${prefix}* [option configure.cxx]] \
                    || [string match ${prefix}* [option configure.objcxx]]} {
                set port [registry_file_registered [option configure.cxx]]
                if {${port} != 0} {
                    puts ${fd} "#    C++ compiler provided by: [lrange [lindex [registry_active ${port}] 0] 0 3]"
                }
                if {[option configure.objcxx] ne [option configure.cxx]} {
                    set port [registry_file_registered [option configure.objcxx]]
                    if {${port} != 0} {
                        puts ${fd} "# ObjC++ compiler provided by: [lrange [lindex [registry_active ${port}] 0] 0 3]"
                    }
                }
            }
            puts ${fd} "# Commandline configure options:"
            if {${configure.optflags} ne ""} {
                puts -nonewline ${fd} " configure.optflags=\"${configure.optflags}\""
            }
            if {${configure.compiler} ne ""} {
                puts -nonewline ${fd} " configure.compiler=\"${configure.compiler}\""
            }
            if {${configureccache} ne ""} {
                puts -nonewline ${fd} " configureccache=\"${configureccache}\""
            }
            if {${configure.cxx_stdlib} ne ""} {
                puts -nonewline ${fd} " configure.cxx_stdlib=\"${configure.cxx_stdlib}\""
            }
            puts ${fd} ""
            puts ${fd} "\ncd ${build.dir}"
            puts ${fd} "${build.cmd} [join ${build.pre_args}] [join ${build.args}] [join ${build.post_args}]"
            close ${fd}
            unset fd
        }
    }
}

proc configure::callback {} {
    global configure.cmd
    if {${configure::statevar}} {
        ui_debug "[dict get [info frame 0] proc]: save_configure_cmd  already called directly by Portfile"
    } elseif {${configure::statevar2}} {
        ui_debug "[dict get [info frame 0] proc]: save_build_cmd  already called directly by Portfile"
    } else {
        if {[string match *cmake ${configure.cmd}]} {
            ui_debug "[dict get [info frame 0] proc]: calling `cmake.save_configure_cmd \"install log\"`"
            cmake.save_configure_cmd "install log"
        } elseif {[string match *meson ${configure.cmd}]} {
            ui_debug "[dict get [info frame 0] proc]: calling `meson.save_configure_cmd \"install log\"`"
            meson.save_configure_cmd "install log"
        } elseif {[string match *qmake ${configure.cmd}]} {
            if {![catch {qmake5.save_configure_cmd "install log"}]} {
                ui_debug "[dict get [info frame 0] proc]: called `qmake5.save_configure_cmd \"install log\"`"
            }
        } else {
            ui_debug "[dict get [info frame 0] proc]: calling `save_configure_cmd \"install log\"`"
            configure.save_configure_cmd "install log"
            # check if the makefile PG is in use; in that case we also (!) want to save
            # call save_build_cmd
            if {[namespace eval [namespace parent] {namespace exists makefile_pg}]} {
                ui_debug "[dict get [info frame 0] proc]: makefile PG in use; calling `save_build_cmd \"install\"`"
                configure.save_build_cmd "install"
            }
        }
    }
}
port::register_callback configure::callback
