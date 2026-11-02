# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4
#
# This PortGroup supports the cargo build system
#
# This PortGroup is designed to be used when cargo is the exclusive build mechanism.
# Use the cargo_fetch PortGroup if cargo is called from other build mechanisms
# (e.g. configure and make).
#
# Usage:
#
# PortGroup     cargo 1.0
#
# See the cargo_fetch PortGroup for more options
#
# With rust.compiler mrustc (see the rust_compiler PortGroup; the default on
# powerpc) minicargo builds the port. With rustc this is the cargo PortGroup
# of the default ports tree, which this file shadows in the overlay.
#

PortGroup                       rust_compiler 1.0

if {${rust.compiler} eq "mrustc"} {
    # (also sets rustc_target_ver, the Rust version of the mrustc port)
    PortGroup                   mrustc 1.0

    default use_configure       no
    default universal_variant   no

    default build.cmd           {MRUSTC_TARGET_VER=${rustc_target_ver} ${cargo.bin} \.}
    default build.target        {}
    # Keep the vendor and output directories out of build.args: a Portfile that sets `build.args --features=..` (websocat)
    # instead of appending would otherwise drop them (minicargo then finds no crate at all)
    default build.pre_args      {-L ${mrustc_root}/lib/ -j${build.jobs} --vendor-dir ${cargo.home}/macports/ --output-dir ${worksrcpath}/target/[cargo.rust_platform]/release}
    default build.args          {}

    destroot {
        ui_error "No destroot phase in the Portfile!"
        ui_msg "Here is an example destroot phase:"
        ui_msg
        ui_msg "destroot {"
        ui_msg {    xinstall -m 0755 ${worksrcpath}/target/[option triplet.${muniversal.build_arch}]/release/${name} ${destroot}${prefix}/bin/}
        ui_msg {    xinstall -m 0444 ${worksrcpath}/doc/${name}.1 ${destroot}${prefix}/share/man/man1/}
        ui_msg "}"
        ui_msg
        ui_msg "Please check if there are additional files (configuration, documentation etc.) that need to be installed."
        error "destroot phase not implemented"
    }
} else {
    rust_compiler::source_default_portgroup cargo
}
