# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# This portgroup is to help bootstrap the primary gcc compiler on systems
# that lack Xcode gcc. It avoids macports clangs and uses gcc10-bootstrap.

proc gcc_dependency.extra_versions {versions} {
    global prefix configure.cxx_stdlib os.arch
    # These are two scenarios when we want to avoid clangs, while MacPorts tries to force them onto us:
    if {(${os.arch} eq "powerpc" && ${configure.cxx_stdlib} eq "libc++") || \
        (${os.arch} ne "powerpc" && ${configure.cxx_stdlib} eq "macports-libstdc++")} {
        foreach ver $versions {
            compiler.blacklist-append macports-clang-${ver}
        }
        configure.compiler.add_deps \
                        no
        depends_build-append \
                        port:gcc10-bootstrap
        configure.cc    ${prefix}/libexec/gcc10-bootstrap/bin/gcc
        configure.cxx   ${prefix}/libexec/gcc10-bootstrap/bin/g++
    }
}

# These are clang versions though:
gcc_dependency.extra_versions {devel 22 21 20 19 18 17 16 15 14 13 12 11 10 9.0 8.0 7.0 6.0 5.0 3.7 3.4}
