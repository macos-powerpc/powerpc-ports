# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4
#
# This PortGroup supports ports whose own build system calls cargo
# (e.g. Python packages built by setuptools-rust).
#
# Usage:
#
# PortGroup     rust 1.0
#
# With rust.compiler mrustc (see the rust_compiler PortGroup; the default on
# powerpc) this is the mrustc PortGroup: it vendors cargo.crates the same way,
# and its cargo and rustc stand-ins (mrustc.cargo_shim) build with minicargo.
# With rustc it is the rust PortGroup of the default ports tree, which this
# file shadows in the overlay.
#

PortGroup                       rust_compiler 1.0

if {${rust.compiler} eq "mrustc"} {
    # This port's build system runs cargo: the mrustc PortGroup gives it the stand-ins (mrustc.cargo_shim)
    namespace eval rust {
        variable runs_cargo yes
    }
    PortGroup                   mrustc 1.0
} else {
    rust_compiler::source_default_portgroup rust
}
