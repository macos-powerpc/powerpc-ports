# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4
#
# This PortGroup supports the cargo build system
#
# This PortGroup is designed to be used when cargo is the
#    exclusive build mechanism.
# Use the cargo_fetch PortGroup if cargo is called from other
#    build mechanisms (e.g. configure and make).
#
# Usage:
#
# PortGroup     cargo 1.0
#
# See the cargo_fetch PortGroup for more options
#

default use_configure           no

global os.arch

if {${os.arch} eq "powerpc"} {
    PortGroup                   mrustc 1.0

    default universal_variant   no

    default build.cmd           {MRUSTC_TARGET_VER=1.54 ${cargo.bin} \.}
    default build.target        {}
    default build.pre_args      {-L ${mrustc_root}/lib/ -j${build.jobs}}
    default build.args          {--vendor-dir ${cargo.home}/macports/ --output-dir ${worksrcpath}/target/[cargo.rust_platform]/release}
} else {
    PortGroup                   rust 1.0

    default universal_variant   yes

    default build.cmd           {${cargo.bin} build}
    default build.target        {}
    default build.pre_args      {--release ${cargo.offline_cmd} -v -j${build.jobs}}
    default build.args          {}
}

# build.dir           ${workpath}
# build.cmd-append    ${worksrcpath}/

destroot {
    ui_error "No destroot phase in the Portfile!"
    ui_msg "Here is an example destroot phase:"
    ui_msg
    ui_msg "destroot {"
    ui_msg {    xinstall -m 0755 ${worksrcpath}/target/[option triplet.${muniversal.build_arch}]/release/${name} ${destroot}${prefix}/bin/}
    ui_msg {    xinstall -m 0444 ${worksrcpath}/doc/${name}.1 ${destroot}${prefix}/share/man/man1/}
    ui_msg "}"
    ui_msg
    ui_msg "Please check if there are additional files (configuration, documentation, etc.) that need to be installed."
    error "destroot phase not implemented"
}
