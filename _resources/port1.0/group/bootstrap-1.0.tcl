# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# This PortGroup provides support for bootstrap builds.
#
# Usage:
# PortGroup             bootstrap 1.0

options                 bootstrap.force_gcc10 bootstrap.use_gcc10

# If default is changed, please make sure to add the option
# explicitly to the ports using it.
default bootstrap.use_gcc10     yes
# The following will force using gcc10-bootstrap.
# This should not be on by default.
default bootstrap.force_gcc10   no

port::register_callback bootstrap.set_build_env

proc bootstrap.set_build_env {} {
    global              bootstrap.force_gcc10 \
                        bootstrap.use_gcc10 \
                        configure.cxx_stdlib \
                        prefix
    # Correct condition is on the C++ runtime.
    # By default we need this only on systems which use libstdc++
    # (i.e. all PowerPC and old Intel ones). However, why not
    # also support custom configurations for development purposes.
    # Switching to libstdc++ in macports.conf will automatically
    # induce the desired behavior: instead of clangs relying on libc++,
    # gcc will be built using gcc10-bootstrap.
    if {[option bootstrap.force_gcc10] || ([option bootstrap.use_gcc10] \
        && ${configure.cxx_stdlib} ne "libc++")} {
        # Make sure to avoid blacklisting all system compilers
        # when boostrap PG is used. We cannot clear blacklist from here.
        # If a portfile blacklists system compilers, Macports base adds
        # unnecessary dependencies, which may result in a vicious cycle.
        # Blacklist is irrelevant anyway, since we set cc and cxx
        # explicitly below.
        depends_build-append \
                        port:gcc10-bootstrap

        configure.cc    ${prefix}/libexec/gcc10-bootstrap/bin/gcc
        configure.cxx   ${prefix}/libexec/gcc10-bootstrap/bin/g++

        # This may be needed for universal builds.
        configure.compiler.add_deps \
                        no
    }
}
