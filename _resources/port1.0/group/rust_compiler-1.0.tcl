# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4
#
# This PortGroup chooses the Rust compiler of the cargo and rust PortGroups,
# rust.compiler:
#
#   mrustc  the mrustc PortGroup: minicargo and mrustc (port mrustc)
#   rustc   the rust and cargo PortGroups of the default ports tree, which
#           this overlay shadows: cargo and rustc (ports rust and cargo)
#
# The first of these that is set is used:
#
#   1. the command line, for the port and the dependencies built with it:
#          sudo port install foo rust.compiler=mrustc
#   2. the Portfile, before its cargo or rust PortGroup line:
#          set rust.compiler rustc
#   3. ${prefix}/etc/macports/macports.conf, for the whole installation:
#          rust_compiler mrustc
#   4. mrustc on powerpc, which has no working rustc
#      (https://github.com/thepowersgang/mrustc/issues/300), else rustc
#
# The ports that build Rust itself (rust, rust-bootstrap, cargo) always use rustc.
#
# The choice is made when the PortGroup is loaded, as it decides which
# PortGroup that is. Portfiles can test ${rust.compiler} after their cargo or
# rust PortGroup line, or after `PortGroup rust_compiler 1.0` before loading one.
#

options rust.compiler

namespace eval rust_compiler {
    variable compilers      {mrustc rustc}
    variable rustc_ports    {rust rust-bootstrap cargo}
}

proc rust_compiler::macports_conf {key} {
    global prefix
    set value {}
    if {![catch {open ${prefix}/etc/macports/macports.conf r} fd]} {
        while {[gets ${fd} line] >= 0} {
            regexp "^${key}\[ \t\]+(\[^ \t#\]+)" ${line} -> value
        }
        close ${fd}
    }
    return ${value}
}

proc rust_compiler::choose {} {
    global user_options os.arch portpath
    variable compilers
    variable rustc_ports

    # (their Portfiles load the PortGroup before they set name)
    if {[file tail ${portpath}] in ${rustc_ports}} {
        set compiler rustc
        set from "a port that builds Rust"
    } elseif {[info exists user_options(rust.compiler)]} {
        set compiler $user_options(rust.compiler)
        set from "the command line"
    } elseif {[info exists ::rust.compiler]} {
        set compiler ${::rust.compiler}
        set from "the Portfile"
    } elseif {[set compiler [rust_compiler::macports_conf rust_compiler]] ne ""} {
        set from "rust_compiler in macports.conf"
    } elseif {${os.arch} eq "powerpc"} {
        set compiler mrustc
        set from "the default on powerpc"
    } else {
        set compiler rustc
        set from "the default"
    }
    if {${compiler} ni ${compilers}} {
        return -code error "rust.compiler ${compiler} (from ${from}) is none of: ${compilers}"
    }
    ui_debug "rust.compiler ${compiler} (from ${from})"
    return ${compiler}
}

set rust_compiler::selected [rust_compiler::choose]
set rust.compiler ${rust_compiler::selected}

# Sources the PortGroup of the default ports tree that the calling PortGroup
# file shadows, in the caller's scope as PortGroup does
proc rust_compiler::source_default_portgroup {group} {
    set groupfile [getdefaultportresourcepath port1.0/group/${group}-1.0.tcl]
    if {[file normalize ${groupfile}] eq [file normalize [info script]]} {
        return -code error "${group}-1.0.tcl: the default ports tree in sources.conf is this overlay, so the ${group} PortGroup for rustc cannot be found"
    }
    uplevel 1 [list source ${groupfile}]
}

proc rust_compiler::check {} {
    variable selected
    if {[option rust.compiler] ne ${selected}} {
        return -code error "rust.compiler was set to [option rust.compiler] after the PortGroup chose ${selected}: set it before the PortGroup line"
    }
}
port::register_callback rust_compiler::check
