# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4
#
# This PortGroup supports ports whose own build system calls cargo
# (e.g. Python packages built by setuptools-rust).
#
# Usage:
#
# PortGroup     rust 1.0
#
# On powerpc this is the mrustc PortGroup: it vendors cargo.crates the same way,
# and its cargo and rustc stand-ins (mrustc.cargo_shim) build with minicargo.
# Elsewhere it is the rust PortGroup of the default ports tree, which this file
# shadows in the overlay.
#

global os.arch

if {${os.arch} eq "powerpc"} {
    # This port's build system runs cargo: the mrustc PortGroup gives it the stand-ins (mrustc.cargo_shim)
    namespace eval rust {
        variable runs_cargo yes
    }
    PortGroup                   mrustc 1.0
} else {
    namespace eval rust {
        variable default_portgroup [getdefaultportresourcepath port1.0/group/rust-1.0.tcl]
    }
    if {[file normalize ${::rust::default_portgroup}] eq [file normalize [info script]]} {
        return -code error "rust-1.0.tcl: the default ports tree in sources.conf is this overlay, so MacPorts' rust PortGroup cannot be found"
    }
    source ${::rust::default_portgroup}
}
