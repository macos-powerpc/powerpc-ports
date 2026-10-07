# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4
#
# This PortGroup supports the Rust language ecosystem via mrustc.
#
# Usage:
#
# PortGroup     mrustc 1.0
#
# cargo.crates \
#     foo  1.0.1  abcdef123456... \
#     bar  2.5.0  fedcba654321...
#
# The cargo.crates option expects a list with 3-tuples consisting of name,
# version, and sha256 checksum. Only sha256 is supported at this time as
# the checksum will be reused by cargo internally.
#
# The list of crates and their checksums can be found in the Cargo.lock file in
# the upstream source code. The cargo2port generator can be used to automate
# updates of this list for new releases.
#
# To get a list of these, run in worksrcdir:
#     cargo update
#     egrep -e '^(name|version|checksum) = ' Cargo.lock | perl -pe 's/^(?:name|version|checksum) = "(.+)"/$1/'
#
# https://github.com/macports/macports-contrib/tree/master/cargo2port/cargo2port.tcl
#
# If Cargo.lock references pre-release versions, or in general references
# crates not published on crates.io, but available from GitHub, also use the
# following:
#
# # download additional crates from github, not published on crates.io
# cargo.crates_github \
#    baz    author/baz  branch  abcdef12345678...commit...abcdef12345678  fedcba654321...
#
# Crates that need fixes for powerpc or old macOS are patched from the shared
# patches in _resources/port1.0/crate_patches (see the README there), so ports
# don't carry their own copies. A port can add its own directories of crate
# patches, named the same way:
#
# cargo.crate_patch_dirs-append ${filespath}/crate_patches
#

# This portgroup is modelled upon rust 1.0, with extra overrides to support powerpc.
# It will evolve, currently some portions below are unneeded or mismatching.
# However, it is already usable in this form.

PortGroup   compiler_wrapper    1.0
PortGroup   muniversal          1.1

# Ideally, we would like to add the openssl PG, however
#     its use of `option_proc` makes changing the default value of `openssl.branch` difficult,
#     and it interferes with our intended use of compiler_wrapper PG
# For now, create an option `openssl.branch` in this PG
# Cargo's interaction with OpenSSL is a bit delicate
# See, e.g.: https://trac.macports.org/ticket/65011
#
# Similarly for legacysupport PG

options     cargo.bin \
            cargo.home \
            cargo.crates \
            cargo.offline_cmd \
            cargo.crates_github \
            cargo.crate_patch_dirs \
            cargo.update \
            mrustc.incremental

set mrustc_root                 ${prefix}/libexec/mrustc

default     cargo.bin           {${mrustc_root}/bin/minicargo}
default     cargo.home          {${workpath}/.home/.cargo}
default     cargo.crates        {}
default     cargo.crates_github {}

# If a dependency has been patched, `--offline` might be a reasonable choice
default     cargo.offline_cmd   {}

# Some packags do not provide Cargo.lock,
# so offer the option of running cargo-update
default     cargo.update        {no}

# Resume an interrupted build after the mrustc port itself was rebuilt. minicargo normally rebuilds every
# crate whose rlib is older than the compiler or than the installed libstd; with this option only changed
# sources and rebuilt dependencies trigger a rebuild (needs `port -o` as well, for the Portfile mtime):
#   sudo port -o build <port> mrustc.incremental=yes
default     mrustc.incremental  {no}
pre-build {
    if {[option mrustc.incremental]} {
        build.env-append        MINICARGO_IGNTOOLS=1
    }
}

# Directories of per-crate patches, see rust::apply_crate_patches.
# The shared ones live next to this PortGroup; [info script] is only this file
# while it is being sourced, so resolve the path now.
namespace eval rust {
    variable crate_patches_dir [file normalize [file join [file dirname [info script]] .. crate_patches]]
}
default     cargo.crate_patch_dirs  {[list ${::rust::crate_patches_dir}]}

# Use `--remap-path-prefix` to prevent build information from being included in installed binaries
options     rust.remap
default     rust.remap          {${cargo.home} "" ${worksrcpath} ""}

# flags to be passed to the rust compiler
# --remap-path-prefix=... is eventually added unless rust.remap is empty
options     rust.flags
default     rust.flags          {}

# compiler runtime library
#     N.B.: `configure.ldflags-append {*}${rust.rt_static_libs}` might be insufficient
#     `rust.rt_static_libs` will not give the correct value until *after* the compiler is active
#     the compiler might not be active immediately if added as a dependency
options     rust.rt_static_libs
default     rust.rt_static_libs     {[rust::get_static_rutime_libraries]}

# force compiler runtime library to be included in link flags
options     rust.add_compiler_runtime
default     rust.add_compiler_runtime   {no}

# The distfiles of the main port will also be stored in this directory,
# but this is the only way to allow reusing the same crates across multiple ports.
default     dist_subdir             {[expr {[llength ${cargo.crates}] > 0 || [llength ${cargo.crates_github}] > 0 ? "cargo-crates" : ${name}}]}
default     extract.only            {[rust::disttagclean $distfiles]}

# To wrap linker, compiler_wrapper PG required existence of configure.ld
options     configure.ld
default     configure.ld            {${configure.cc}}

# Rust set its own compiler flags, so make empty by default
default     configure.cflags        {}
default     configure.cxxflags      {}
default     configure.ldflags       {[expr {${rust.add_compiler_runtime} ? ${rust.rt_static_libs} : {}} ]}
default     compiler.limit_flags    {yes}
default     configure.pipe          {no}
rename      portconfigure::should_add_stdlib  portconfigure::should_add_stdlib_real
rename      portconfigure::should_add_cxx_abi portconfigure::should_add_cxx_abi_real
proc        portconfigure::should_add_stdlib  {} {return no}
proc        portconfigure::should_add_cxx_abi {} {return no}

# enforce same compiler settings as used by rust
default     compiler.cxx_standard           2017
default     compiler.thread_local_storage   yes

# do not include os.major in target triplet
default     triplet.os              {${os.platform}}

# Rust does not easily pass external flags to compilers, so add them to compiler wrappers
default     compwrap.compilers_to_wrap          {cc cxx ld}
default     compwrap.ccache_supported_compilers {}

# possible OpenSSL versions: empty, 3, 1.1, and 1.0
# Ports with openssl-sys among their crates get MacPorts openssl3 unless they set a
# branch, so its build script never has to look for an OpenSSL (see rust::set_environment).
options     openssl.branch
default     openssl.branch      {[expr {[rust::uses_crate openssl-sys] ? 3 : {}}]}

# Fail destroot if a binary links the system OpenSSL or libcurl, or uses
# SecureTransport (see rust::check_system_tls)
options     mrustc.check_tls
default     mrustc.check_tls    {yes}

####################################################################################################################################
# utility procedures
####################################################################################################################################

# MacPorts architecture name --> Rust architecture name
proc rust.rust_arch {arch} {
    switch ${arch} {
        arm64       {return aarch64}
        i386        {return i686}
        ppc         {return powerpc}
        ppc64       {return powerpc64}
        default     {return ${arch}}
    }
}

# Rust architecture name --> MacPorts architecture name
proc rust.marcports_arch {rarch} {
    switch ${rarch} {
        aarch64     {return arm64}
        i686        {return i386}
        powerpc     {return ppc}
        powerpc64   {return ppc64}
        default     {return ${rarch}}
    }
}

####################################################################################################################################
# compatibility procedures
####################################################################################################################################
proc cargo.rust_platform {{arch ""}} {
    if {${arch} eq ""} {
        set arch [option muniversal.build_arch]
        # muniversal.build_arch is empty if we are not doing a universal build
        if {${arch} eq ""} {
            set arch [option configure.build_arch]
            if {${arch} eq ""} {
                error "No build arch configured"
            }
        }
    }
    return [option triplet.${arch}]
}

####################################################################################################################################
# internal procedures
####################################################################################################################################

namespace eval rust {}

# Is crate `cname` among cargo.crates or cargo.crates_github?
proc rust::uses_crate {cname} {
    foreach {name cversion chksum} [option cargo.crates] {
        if {${name} eq ${cname}} {
            return 1
        }
    }
    foreach {name cgithub cbranch crevision chksum} [option cargo.crates_github] {
        if {${name} eq ${cname}} {
            return 1
        }
    }
    return 0
}

# for symbol ___emutls_get_address (used when thread-local-storage is emulated)
#
# for Clang, provides symbol ___muloti4
# since https://github.com/rust-lang/rust/commit/8a6ff90a3a41e6ace18aeb089ea0a0eb3726dd08
#
proc rust::get_static_rutime_libraries {} {
    set libs [list ]

    if {[string match *clang* [option configure.compiler]]} {
        set libName lib/[option os.platform]/libclang_rt.osx.a
    } else {
        set libName libgcc_eh.a
    }

    if {![catch [list exec [option configure.cc] --print-search-dirs] results]} {
        foreach ln [split ${results} \n] {
            set splt [split ${ln} =]
            if {[lindex ${splt} 0] eq "libraries: "} {
                foreach dir [split [lindex ${splt} 1] :] {
                    set fl [string trimright ${dir} "/"]/${libName}
                    if {[file exists ${fl}]} {
                        lappend libs ${fl}
                    }
                }
            }
        }
    }

    return ${libs}
}

proc rust::configure_ldflags_proc {option action args} {
    if {$action ne "read"} return
    if {[option rust.add_compiler_runtime]} {
        configure.ldflags-delete    {*}[option rust.rt_static_libs]
        configure.ldflags-append    {*}[option rust.rt_static_libs]
    }
}
option_proc configure.ldflags rust::configure_ldflags_proc

# Based on portextract::disttagclean from portextract.tcl
proc rust::disttagclean {list} {
    if {$list eq ""} {
        return $list
    }
    foreach fname $list {
        set name [getdistname ${fname}]

        set is_crate no
        foreach {cname cversion chksum} [option cargo.crates] {
            set cratefile ${cname}-${cversion}.crate
            if {${name} eq ${cratefile}} {
                set is_crate yes
            }
        }
        foreach {cname cgithub cbranch crevision chksum} [option cargo.crates_github] {
            set cratefile ${cname}-${crevision}.tar.gz
            if {${name} eq ${cratefile}} {
                set is_crate yes
            }
        }
        if {!${is_crate}} {
            lappend val ${name}
        }
    }
    return $val
}

proc rust::handle_crates {} {
    foreach {cname cversion chksum} [option cargo.crates] {
        # The same crate name can appear with multiple versions. Use
        # a combination of crate name and checksum as unique identifier.
        # As the :disttag cannot contain dots, the version number cannot be
        # used.
        # To download the crate file curl-0.4.11.crate, the URL is
        #    https://crates.io/api/v1/crates/curl/0.4.11/download.
        # Use ?dummy= to ignore ${distfile}
        # see https://trac.macports.org/wiki/PortfileRecipes#fetchwithgetparams
        set cratefile       ${cname}-${cversion}.crate
        set cratetag        crate-${cname}-${chksum}
        distfiles-append    ${cratefile}:${cratetag}
        master_sites-append https://crates.io/api/v1/crates/${cname}/${cversion}/download?dummy=:${cratetag}
        checksums-append    ${cratefile} sha256 ${chksum}
    }

    foreach {cname cgithub cbranch crevision chksum} [option cargo.crates_github] {
        set cratefile       ${cname}-${crevision}.tar.gz
        set cratetag        crate-${cname}-${chksum}
        distfiles-append    ${cratefile}:${cratetag}
        master_sites-append https://github.com/${cgithub}/archive/${crevision}.tar.gz?dummy=:${cratetag}
        checksums-append    ${cratefile} sha256 ${chksum}
    }
}
port::register_callback rust::handle_crates

proc rust::extract_crate {cratefile} {
    set tar [findBinary tar ${portutil::autoconf::tar_path}]
    system -W "[option cargo.home]/macports" "$tar -xf [shellescape [option distpath]/${cratefile}]"
}

proc rust::write_cargo_checksum {cdirname chksum} {
    # although cargo will never see the .crate, it expects to find the sha256 checksum here
    set chkfile [open "[option cargo.home]/macports/${cdirname}/.cargo-checksum.json" "w"]
    puts $chkfile "{"
    puts $chkfile "    \"package\": ${chksum},"
    puts $chkfile "    \"files\": {}"
    puts $chkfile "}"
    close $chkfile
}

proc rust::old_macos_compatibility {cname cversion} {
    global cargo.home subport

    switch ${cname} {
        "cc" {
            if {[vercmp ${cversion} < 1.0.94] && [vercmp ${cversion} >= 1.0.85]} {
                # see https://github.com/rust-lang/cc-rs/pull/1007
                reinplace "s|--show-sdk-platform-version|--show-sdk-version|g" \
                    ${cargo.home}/macports/${cname}-${cversion}/src/lib.rs
            }
        }
        "cmake" {
            if {[vercmp ${cversion} >= 0.1.49]} {
                # cmake-rs sets CMAKE_OSX_ARCHITECTURES only for x86_64 and aarch64 and panics
                # ("unsupported darwin target") on every other Darwin target
                reinplace {s|panic!("unsupported darwin target: {}", target);|if target.contains("powerpc64") { cmd.arg("-DCMAKE_OSX_ARCHITECTURES=ppc64"); } else if target.contains("powerpc") { cmd.arg("-DCMAKE_OSX_ARCHITECTURES=ppc"); } else if target.contains("i686") { cmd.arg("-DCMAKE_OSX_ARCHITECTURES=i386"); } else { panic!("unsupported darwin target: {}", target); }|} \
                    ${cargo.home}/macports/${cname}-${cversion}/src/lib.rs
            }
        }
        "curl-sys" {
            if {[vercmp ${cversion} < 0.4.56]} {
                # On Mac OS X 10.6, clang exists, but `clang --print-search-dirs` returns an empty library directory.
                # See: https://github.com/alexcrichton/curl-rust/commit/b3a3ce876921f2e82a145d9abd539cd8f9b7ab7b
                # See: https://trac.macports.org/ticket/64146#comment:16
                # On 10.6 PowerPC we do not want clang at all.
                # On other systems, we want the static library of the compiler we are using and not necessarily the system compiler.
                # See: https://github.com/alexcrichton/curl-rust/commit/a6969c03b1e8f66bc4c801914327176ed38f44c5
                # See: https://github.com/alexcrichton/curl-rust/issues/279
                # For upstream pull request, see https://github.com/alexcrichton/curl-rust/pull/451
                reinplace "s|Command::new(\"clang\")|cc::Build::new().get_compiler().to_command()|g" \
                    ${cargo.home}/macports/${cname}-${cversion}/build.rs
            }
        }
        "gmp-mpfr-sys" {
            # GMP's configure auto-detects the host CPU; on a G5 it selects 64-bit
            # limbs (abilist "mode64 mode32 32") that don't build with 32-bit CFLAGS.
            # Pin the ABI to the Rust target instead of the host CPU.
            if {[option configure.build_arch] eq "ppc"} {
                reinplace {s|"../gmp-src/configure --enable-fat --disable-shared --with-pic"|"../gmp-src/configure --enable-fat --disable-shared --with-pic ABI=32"|} \
                    ${cargo.home}/macports/${cname}-${cversion}/build.rs
            }
        }
        "kqueue" {
            if {[vercmp ${cversion} < 1.0.5] && "i386" in [option muniversal.architectures]} {
                # see https://gitlab.com/worr/rust-kqueue/-/merge_requests/10
                reinplace {s|all(target_os = "freebsd", target_arch = "x86")|all(any(target_os = "freebsd", target_os = "macos"), any(target_arch = "x86", target_arch = "powerpc"))|g} \
                    ${cargo.home}/macports/${cname}-${cversion}/src/time.rs
                cargo.offline_cmd-replace --frozen --offline
            }
        }
        "ptyprocess" {
            # `ioctl`'s `request` argument is `c_ulong`, which is 32-bit on
            # 32-bit targets (e.g. powerpc); ptyprocess casts the constant to
            # a hard-coded `u64`, giving "Type mismatch between u32 and u64".
            # `as _` lets the type be inferred, so it is correct on every arch.
            # See src/lib.rs get_slave_name (macos).
            reinplace "s|TIOCPTYGNAME as u64|TIOCPTYGNAME as _|g" \
                ${cargo.home}/macports/${cname}-${cversion}/src/lib.rs
        }
        "rustix" {
            if {[vercmp ${cversion} < 0.38.31] && [vercmp ${cversion} >= 0.0] && ("i386" in [option muniversal.architectures] || "ppc" in [option muniversal.architectures])} {
                # see https://github.com/bytecodealliance/rustix/issues/991
                reinplace "s|utimensat_old(dirfd, path, times, flags)|//utimensat_old(dirfd, path, times, flags)|g" \
                    ${cargo.home}/macports/${cname}-${cversion}/src/backend/libc/fs/syscalls.rs
                reinplace "s|futimens_old(fd, times)|//futimens_old(fd, times)|g" \
                    ${cargo.home}/macports/${cname}-${cversion}/src/backend/libc/fs/syscalls.rs
                reinplace "s|pub last_access: Timespec,|pub last_access: c::timespec,|g" \
                    ${cargo.home}/macports/${cname}-${cversion}/src/fs/fd.rs
                reinplace "s|pub last_modification: Timespec|pub last_modification: c::timespec|g" \
                    ${cargo.home}/macports/${cname}-${cversion}/src/fs/fd.rs
                reinplace -E "s|^(//! Functions which operate on file descriptors\.)|\\1\\\nuse crate::backend::c;|" \
                    ${cargo.home}/macports/${cname}-${cversion}/src/fs/fd.rs
            }
        }
    }

    # rust-bootstrap requires `macosx_deployment_target` instead of `os.major`
    if {[option os.platform] ne "darwin" || [vercmp [option macosx_deployment_target] >= 10.8]} {
        return
    }

    switch ${cname} {
        "cc" {
            if {[vercmp ${cversion} >= 1.0.85]} {
                # cc ignores `MACOSX_DEPLOYMENT_TARGET` if it is too low (see https://github.com/rust-lang/cc-rs/commit/0a0ce5726d0b42d383bb50079bdb680dfddcc076)
                # instead, cc runs `xcrun --show-sdk-platform-version` or `xcrun --show-sdk-version`, depening on the version of cc
                # `xcrun --show-sdk-platform-version` was a mistake (see https://github.com/rust-lang/cc-rs/pull/1007)
                # `xcrun --show-sdk-version` is only supported on 10.8 or above
                # if `xcrun` fails, cc sets MACOSX_DEPLOYMENT_TARGET to a hardcoded value
                # cc may remove `xcrun` in the future (see https://github.com/rust-lang/cc-rs/pull/1009)
                reinplace "s|let default = \"10.7\";|let default = \"[option macosx_deployment_target]\";|g" \
                    ${cargo.home}/macports/${cname}-${cversion}/src/lib.rs
            }
        }
        "crossbeam-utils" {
            if {[vercmp ${cversion} >= 0.8.5]} {
                reinplace "s|\"powerpc-unknown-linux-gnu\"|\"powerpc-apple-darwin\"|" \
                    ${cargo.home}/macports/${cname}-${cversion}/no_atomic.rs
            }
        }
        "crypto-hash" {
            # switch crypto-hash to use openssl instead of commoncrypto
            # See: https://github.com/malept/crypto-hash/issues/23
            reinplace "s|target_os = \"macos\"|target_os = \"macos_disabled\"|g" \
                ${cargo.home}/macports/${cname}-${cversion}/src/lib.rs
            reinplace "s|macos|macos_disabled|g" \
                ${cargo.home}/macports/${cname}-${cversion}/Cargo.toml
        }
        "curl-sys" {
            if {[vercmp ${cversion} < 0.4.83]} {
                # curl-sys requires CCDigestGetOutputSizeFromRef which is only available since macOS 10.8
                # disable USE_SECTRANSP to avoid calling of CCDigestGetOutputSizeFromRef and use OpenSSL instead
                # (the Cargo.toml change makes openssl-sys a dependency on macOS)
                # See: https://github.com/alexcrichton/curl-rust/issues/429
                # This is only for the vendored curl (static-curl, or no usable libcurl found).
                # curl 8.15.0 (curl-sys 0.4.83) dropped SecureTransport and depends on openssl-sys on all unix:
                # https://github.com/alexcrichton/curl-rust/commit/8b34786fdd93d4c3eca5c66a8374631284dfe576
                reinplace "s|else if target.contains(\"-apple-\")|else if target.contains(\"-apple_disabled-\")|g" \
                    ${cargo.home}/macports/${cname}-${cversion}/build.rs
                reinplace "s|macos|macos_disabled|g" \
                    ${cargo.home}/macports/${cname}-${cversion}/Cargo.toml
            }
        }
        "jemalloc" {
            # This is for Darwin:
            reinplace "s|ifdef __powerpc__|ifdef __POWERPC__|" \
                ${cargo.home}/macports/${cname}-${cversion}/rep/include/jemalloc/internal/quantum.h
        }
        "libc" {
            # Add support for powerpc. Later versions use pointer width instead of hardcoded archs.
            if {[vercmp ${cversion} < 0.2.121]} {
                reinplace "s|target_arch = \"arm\"\, target_arch = \"x86\"|target_arch = \"arm\"\, target_arch = \"powerpc\"\, target_arch = \"x86\"|" \
                    ${cargo.home}/macports/${cname}-${cversion}/src/unix/bsd/apple/mod.rs
                reinplace "s|target_arch = \"x86_64\"\, target_arch = \"aarch64\"|target_arch = \"aarch64\"\, target_arch = \"powerpc64\"\, target_arch = \"x86_64\"|" \
                    ${cargo.home}/macports/${cname}-${cversion}/src/unix/bsd/apple/mod.rs
            }
        }
        "libgit2-sys" {
            # libgit2-sys requires SSLCreateContext which is only available since macOS 10.8
            # disable GIT_SECURE_TRANSPORT to avoid calling of SSLCreateContext and use OpenSSL instead
            # (from 0.14 this also switches SHA256 from CommonCrypto to OpenSSL)
            reinplace "s|else if target.contains(\"apple\")|else if target.contains(\"apple_disabled\")|g" \
                ${cargo.home}/macports/${cname}-${cversion}/build.rs
            if {[vercmp ${cversion} >= 0.12.2] && [vercmp ${cversion} < 0.13.3]} {
                # These accept any system libgit2 at least as new as the bundled one (pkg-config
                # atleast_version), so they would bind to MacPorts libgit2 1.9 with an incompatible
                # ABI. Make the probe fail so the bundled libgit2 is built.
                reinplace "s|.probe(\"libgit2\")|.probe(\"libgit2-abi-mismatch\")|" \
                    ${cargo.home}/macports/${cname}-${cversion}/build.rs
            }
        }
    }

    if {[option os.platform] ne "darwin" || [vercmp [option macosx_deployment_target] >= 10.7]} {
        return
    }

    switch ${cname} {
        "cc" {
            if {[vercmp ${cversion} < 1.1.1] && [vercmp ${cversion} >= 1.0.85]} {
                reinplace "s|\"i686\" => AppleArchSpec::Device(\"-m32\")|\"powerpc\" => AppleArchSpec::Device(\"-m32\")|" \
                    ${cargo.home}/macports/${cname}-${cversion}/src/lib.rs
                reinplace "s|\"aarch64\" => AppleArchSpec::Device(\"-m64\")|\"powerpc64\" => AppleArchSpec::Device(\"-m64\")|" \
                    ${cargo.home}/macports/${cname}-${cversion}/src/lib.rs
            }
        }
    }

    if {[option os.platform] ne "darwin" || [vercmp [option macosx_deployment_target] >= 10.6]} {
        return
    }

    switch ${cname} {
        "cargo-util" {
            reinplace {s|#\[cfg(not(target_os = "macos"))\]|#\[cfg(not(target_os = "macos_temp"))\]|g} \
                ${cargo.home}/macports/${cname}-${cversion}/src/paths.rs
            reinplace {s|#\[cfg(target_os = "macos")\]|#\[cfg(not(target_os = "macos"))\]|g} \
                ${cargo.home}/macports/${cname}-${cversion}/src/paths.rs
            reinplace {s|#\[cfg(not(target_os = "macos_temp"))\]|#\[cfg(target_os = "macos")\]|g} \
                ${cargo.home}/macports/${cname}-${cversion}/src/paths.rs
        }
        "notify" {
            reinplace {s|default = \["macos_fsevent"\]|default = \["macos_kqueue"\]|g} \
                ${cargo.home}/macports/${cname}-${cversion}/Cargo.toml
        }
    }
}

# Per-crate patches
#
# Each directory in cargo.crate_patch_dirs holds patches named
#     <crate>@<version>.patch         this version only
#     <crate>@<from>..<to>.patch      from <= version <= to
#     <crate>@<from>+.patch           from <= version
# Every patch whose range includes the crate's version is applied right after
# the crate is unpacked, in directory order and then by name. Paths in the
# patches are relative to the crate's root (a/src/lib.rs, b/src/lib.rs), so one
# file serves every version the patch applies to. Versions are compared with
# vercmp. Crates from GitHub only match <crate>@<commit>.patch.

proc rust::crate_patch_matches {spec cversion exact_only} {
    if {${spec} eq ${cversion}} {
        return 1
    }
    if {${exact_only}} {
        return 0
    }
    if {[string index ${spec} end] eq "+"} {
        return [vercmp ${cversion} >= [string range ${spec} 0 end-1]]
    }
    set sep [string first .. ${spec}]
    if {${sep} < 0} {
        return 0
    }
    set from [string range ${spec} 0 ${sep}-1]
    set to   [string range ${spec} ${sep}+2 end]
    return [expr {[vercmp ${cversion} >= ${from}] && [vercmp ${cversion} <= ${to}]}]
}

proc rust::crate_patches {cname cversion exact_only} {
    set patches [list]
    foreach dir [option cargo.crate_patch_dirs] {
        foreach patchfile [lsort [glob -nocomplain -types f -directory ${dir} -- ${cname}@*.patch]] {
            set spec [string range [file tail ${patchfile}] [string length ${cname}@] end-[string length .patch]]
            if {[rust::crate_patch_matches ${spec} ${cversion} ${exact_only}]} {
                lappend patches ${patchfile}
            }
        }
    }
    return ${patches}
}

proc rust::apply_crate_patches {cname cversion cdirname exact_only} {
    set patchbin [findBinary patch ${portutil::autoconf::patch_path}]
    foreach patchfile [rust::crate_patches ${cname} ${cversion} ${exact_only}] {
        set pname [file tail ${patchfile}]
        ui_info "Applying ${pname} to ${cdirname}"
        if {[catch {system -W "[option cargo.home]/macports/${cdirname}" "${patchbin} -p1 -t -N < [shellescape ${patchfile}]"} result]} {
            ui_error "${pname} ([file dirname ${patchfile}]) does not apply to ${cname} ${cversion}."
            ui_error "If ${cname} ${cversion} no longer needs it, rename the patch so its version range ends before ${cversion}; otherwise update the patch or add one for ${cname} ${cversion}."
            return -code error ${result}
        }
    }
}

proc rust::import_crate {cname cversion chksum cratefile} {
    global cargo.home

    ui_info "Adding ${cratefile} to cargo home"
    rust::extract_crate ${cratefile}
    rust::write_cargo_checksum "${cname}-${cversion}" "\"${chksum}\""
    rust::old_macos_compatibility ${cname} ${cversion}
    rust::apply_crate_patches ${cname} ${cversion} "${cname}-${cversion}" no
}

proc rust::import_crate_github {cname cgithub crevision chksum cratefile} {
    global cargo.home

    set crepo [lindex [split ${cgithub} "/"] 1]
    set cdirname "${crepo}-${crevision}"

    ui_info "Adding ${cratefile} from github to cargo home"
    rust::extract_crate ${cratefile}
    rust::write_cargo_checksum ${cdirname} "null"
    rust::old_macos_compatibility ${cname} ${crevision}
    rust::apply_crate_patches ${cname} ${crevision} ${cdirname} yes
}

post-extract {
    if {[llength ${cargo.crates}] > 0 || [llength ${cargo.crates_github}]>0} {
        file mkdir "${cargo.home}/macports"

        foreach dir ${cargo.crate_patch_dirs} {
            if {![file isdirectory ${dir}]} {
                ui_warn "cargo.crate_patch_dirs: ${dir} is not a directory"
            }
        }

        # Avoid downloading files from online repository during build phase,
        # use a replacement for crates.io
        # https://doc.rust-lang.org/cargo/reference/source-replacement.html
        set conf [open "${cargo.home}/config.toml" "w"]
        puts $conf "\[source\]"
        puts $conf "\[source.macports\]"
        puts $conf "directory = \"${cargo.home}/macports\""
        puts $conf "\[source.crates-io\]"
        puts $conf "replace-with = \"macports\""
        puts $conf "local-registry = \"/var/empty\""
        foreach {cname cgithub cbranch crevision chksum} ${cargo.crates_github} {
            puts $conf "\[source.\"https://github.com/${cgithub}\"\]"
            puts $conf "git = \"https://github.com/${cgithub}\""
            puts $conf "branch = \"${cbranch}\""
            puts $conf "replace-with = \"macports\""
        }
        close $conf

        # import all crates
        foreach {cname cversion chksum} ${cargo.crates} {
            set cratefile ${cname}-${cversion}.crate
            rust::import_crate ${cname} ${cversion} ${chksum} ${cratefile}
        }
        foreach {cname cgithub cbranch crevision chksum} ${cargo.crates_github} {
            set cratefile ${cname}-${crevision}.tar.gz
            rust::import_crate_github ${cname} ${cgithub} ${crevision} ${chksum} ${cratefile}
        }
    }

    if {${subport} ne "rust" && [join [lrange [split ${subport} -] 0 1] -] ne "rust-bootstrap"} {

        # See comment below concerning RUSTC and RUSTFLAGS

        file mkdir "${cargo.home}"
        set conf [open "${cargo.home}/config.toml" "a"]

        puts $conf "\[build\]"
        puts $conf "rustc = \"${prefix}/bin/rustc\""
        if {[option rust.flags] ne ""} {
            puts $conf "rustflags = \[\"[join [option rust.flags] {", "}]\"\]"
        }

        # be sure to include all architectures in case, e.g., a 64-bit Cargo compiles a 32-bit port
        foreach arch {arm64 x86_64 i386 ppc ppc64} {
            puts $conf "\[target.[option triplet.${arch}]\]"
            puts $conf "linker = \"[compwrap::wrap_compiler ld]\""
        }
        close $conf
    }
}

proc rust::append_envs { var {phases {configure build destroot}} } {
    foreach phase ${phases} {
        ${phase}.env-delete ${var}
        ${phase}.env-append ${var}
    }
}

# Utility procedure to find SDK
proc rust::get_sdkroot {sdk_version} {
    if {[option os.platform] ne "darwin"} {
        # only valid empty return
        return {}
    }

    if {[option configure.sdkroot] ne ""} {
        # SDK from base was found, so trust it
        return [option configure.sdkroot]
    }

    if {![option use_xcode] && [file exists "/Library/Developer/CommandLineTools/SDKs"]} {
        set sdks_dir        /Library/Developer/CommandLineTools/SDKs
    } else {
        # `configure.developer_dir` is not used in case `use_xcode` is true but SDKs directory does not exist
        # early command line tools did not install SDKs
        if {[vercmp [option xcodeversion] < 4.3]} {
            set sdks_dir    [option developer_dir]/SDKs
        } else {
            set sdks_dir    [option developer_dir]/Platforms/MacOSX.platform/Developer/SDKs
        }
    }

    if {$sdk_version eq "10.4"} {
        set sdk ${sdks_dir}/MacOSX10.4u.sdk
    } else {
        set sdk ${sdks_dir}/MacOSX${sdk_version}.sdk
    }
    if {[file exists ${sdk}]} {
        # exact SDK was found
        return ${sdk}
    }

    set sdk_major [lindex [split $sdk_version .] 0]

    set sdks [glob -nocomplain -directory ${sdks_dir} MacOSX${sdk_major}*.sdk]
    foreach sdk [lreverse [lsort -command vercmp $sdks]] {
        # Sanity check - mostly empty SDK directories are known to exist
        if {[file exists ${sdk}/usr/include/sys/cdefs.h]} {
            # SDK with same OS version found
            return ${sdk}
        }
    }

    if {$sdk_major >= 11 && $sdk_major == [option macos_version_major]} {
        set try_versions [list ${sdk_major}.0 [option macos_version]]
    } elseif {[option os.major] >= 12} {
        set try_versions [list $sdk_version]
    } else {
        # `xcrun --show-sdk-path` fails prior to 10.8
        set try_versions [list]
    }
    foreach try_version $try_versions {
        if {![catch {exec env DEVELOPER_DIR=[option configure.developer_dir] xcrun --sdk macosx${try_version} --show-sdk-path 2> /dev/null} sdk]} {
            # xcrun found SDK with same OS version
            return ${sdk}
        }
    }

    set sdk ${sdks_dir}/MacOSX.sdk
    if {[file exists ${sdk}]} {
        # unversioned SDK found
        ui_warn "Rust PG: Unversioned SDK ${sdk} used for ${sdk_version}"
        return ${sdk}
    }

    if {[option os.major] >= 12} {
        # `xcrun --show-sdk-path` fails prior to 10.8
        if {![catch {exec xcrun --sdk macosx --show-sdk-path 2> /dev/null} sdk]} {
            # xcrun found unversioned SDK
            ui_warn "Rust PG: Unversioned SDK ${sdk} used for ${sdk_version}"
            return ${sdk}
        }
    }

    ui_error "Rust PG: unable to find SDK for ${sdk_version}"
    return {}
}

proc rust::set_environment {} {
    global prefix configure.pkg_config_path
    global subport configure.build_arch configure.universal_archs

    rust::append_envs     "RUST_BACKTRACE=1"
    rust::append_envs     "MRUSTC_LIFETIME_ERRORS=warn"     {build destroot}

    rust::append_envs     CC=[compwrap::wrap_compiler cc]   {build destroot}
    rust::append_envs     CXX=[compwrap::wrap_compiler cxx] {build destroot}

    # cc (and link-cplusplus, which goes through it) links C++ code with -lc++ on every Apple
    # target, but GCC uses libstdc++, and so does clang unless the C++ library is libc++
    if {[option os.platform] eq "darwin" && ([string match *gcc* [option configure.compiler]] || [option configure.cxx_stdlib] ne "libc++")} {
        rust::append_envs CXXSTDLIB=stdc++ {build destroot}
    }

    if { [option openssl.branch] ne "" } {
        set openssl_ver                     [string map {. {}} [option openssl.branch]]
        rust::append_envs                   OPENSSL_DIR=${prefix}/libexec/openssl${openssl_ver}
        # Also when some crate turns on openssl-sys/vendored: openssl-src has no
        # powerpc-apple-darwin target, and its OPENSSLDIR would be /usr/local/ssl.
        rust::append_envs                   OPENSSL_NO_VENDOR=1
        compiler.cpath-prepend              ${prefix}/libexec/openssl${openssl_ver}/include
        compiler.library_path-prepend       ${prefix}/libexec/openssl${openssl_ver}/lib
        configure.pkg_config_path-prepend   ${prefix}/libexec/openssl${openssl_ver}/lib/pkgconfig
    }

    # Propagate pkgconfig path to build and destroot phases as well.
    # Needed to work with openssl PG.
    if { ${configure.pkg_config_path} ne "" } {
        rust::append_envs "PKG_CONFIG_PATH=[join ${configure.pkg_config_path} :]" {build destroot}
    }

    if {${subport} ne "rust" && [join [lrange [split ${subport} -] 0 1] -] ne "rust-bootstrap"} {

        # when CARGO_BUILD_TARGET is set or `--target` is used, RUSTFLAGS and RUSTC are ignored
        #     rust::append_envs     "RUSTFLAGS=-C linker=[compwrap::wrap_compiler ld]"
        #     rust::append_envs     "RUSTC=${prefix}/bin/rustc"
        # see https://github.com/rust-lang/cargo/issues/4423

        foreach stage {configure build destroot} {
            foreach arch [option muniversal.architectures] {
                ${stage}.env.${arch}-append "CARGO_BUILD_TARGET=[option triplet.${arch}]"
            }
        }
    }
}
port::register_callback rust::set_environment

# Mac OS X 10.4-10.6 ship OpenSSL 0.9.7/0.9.8 and a libcurl built on it in /usr/lib, and
# SecureTransport only speaks TLS 1.0 and trusts the root certificates of that release.
# Crates fall back to them quietly (curl-sys `-l curl`, Security.framework backends), and
# such binaries link but cannot talk to current servers. Executables are linked with
# -dead_strip, so a SecureTransport import here is actually used.
proc rust::is_macho {f} {
    if {[catch {open ${f} r} fd]} {
        return 0
    }
    fconfigure ${fd} -translation binary
    set magic [read ${fd} 4]
    close ${fd}
    if {[binary scan ${magic} H8 hex] != 1} {
        return 0
    }
    return [expr {${hex} in {feedface cefaedfe feedfacf cffaedfe cafebabe}}]
}

proc rust::check_system_tls {} {
    set destroot    [option destroot]
    set bad_libs    {/usr/lib/libssl.* /usr/lib/libcrypto.* /usr/lib/libcurl.*}
    set bad_syms    {_SSLCreateContext _SSLNewContext _SSLHandshake
                     _SecTrustSettingsCopyCertificates _SecTrustCopyAnchorCertificates}
    set problems    [list]
    # (no `continue` in the body: on a directory, fs-traverse skips its contents)
    fs-traverse f [list ${destroot}] {
        if {[file type ${f}] eq "file" && [rust::is_macho ${f}]} {
            set rel [string range ${f} [string length ${destroot}] end]
            if {![catch {exec otool -L ${f}} out]} {
                foreach ln [lrange [split ${out} \n] 1 end] {
                    set lib [lindex [string trim ${ln}] 0]
                    foreach pat ${bad_libs} {
                        if {[string match ${pat} ${lib}]} {
                            lappend problems "${rel} links ${lib}"
                        }
                    }
                }
            }
            if {![catch {exec nm -u ${f}} out]} {
                foreach sym [split ${out} \n] {
                    set sym [string trim ${sym}]
                    if {${sym} in ${bad_syms}} {
                        lappend problems "${rel} uses ${sym} (Security.framework)"
                    }
                }
            }
        }
    }
    if {[llength ${problems}] > 0} {
        foreach p [lsort -unique ${problems}] {
            ui_error "mrustc PG: ${p}"
        }
        ui_error "Use MacPorts openssl3/curl and curl-ca-bundle instead (crate patches, Portfile features),"
        ui_error "or set mrustc.check_tls no if this binary really should use the system TLS stack."
        return -code error "binaries use the system TLS stack"
    }
}

post-destroot {
    if {[option mrustc.check_tls]} {
        rust::check_system_tls
    }
}

proc rust::rust_pg_callback {} {
    global  subport \
            prefix

    if {${subport} ne "rust" && [join [lrange [split ${subport} -] 0 1] -] ne "rust-bootstrap"} {
        # port is *not* building Rust

        foreach {f s} [option rust.remap] {
            rust.flags-prepend          --remap-path-prefix=${f}=${s}
        }

        depends_build-delete            port:mrustc
        depends_build-append            port:mrustc
    }

    if { [option openssl.branch] ne "" } {
        set openssl_ver                 [string map {. {}} [option openssl.branch]]
        depends_lib-delete              port:openssl${openssl_ver}
        depends_lib-append              port:openssl${openssl_ver}
        # OpenSSL's cert.pem is a link to the curl-ca-bundle file, which openssl does not install
        depends_run-delete              port:curl-ca-bundle
        depends_run-append              port:curl-ca-bundle
    }

    # Without static-curl, curl-sys links `-l curl` with no search path on macOS, which is
    # ${prefix}/lib/libcurl.dylib (LIBRARY_PATH, and std's ${prefix}/lib) only if curl is
    # installed - otherwise /usr/lib/libcurl.dylib, built on the system OpenSSL 0.9.x.
    if {[rust::uses_crate curl-sys]} {
        depends_lib-delete              port:curl
        depends_lib-append              port:curl
    }

    # rust-bootstrap requires `macosx_deployment_target` instead of `os.major`
    if {[option os.platform] eq "darwin" && [vercmp [option macosx_deployment_target] < 10.12]} {
        if { [join [lrange [split ${subport} -] 0 1] -] eq "rust-bootstrap" } {
            # Bootstrap compilers are building on newer machines to be run on older ones.
            # Use libMacportsLegacySystem.B.dylib since it is able to use the `__asm("$ld$add$os10.5$...")` trick for symbols that are part of legacy-support *only* on older systems.
            set legacyLib               libMacportsLegacySystem.B.dylib
            set dep_type                lib
        } else {
            # Use the static library since the Rust compiler looks up certain symbols at *runtime* (e.g. `openat`).
            # Normally, we would want the additional functionality provided by MacPorts.
            # However, for reasons yet unknown, the Rust file system (sys/unix/fs.rs) functions fail when they try to use MacPorts system calls.
            set legacyLib               libMacportsLegacySupport.a
            set dep_type                build
        }

        # LLVM: CFPropertyListCreateWithStream, uuid_string_t
        # Rust: _posix_memalign, extended _realpath, _pthread_setname_np, _copyfile_state_get
        depends_${dep_type}-delete      path:lib/${legacyLib}:legacy-support
        depends_${dep_type}-append      path:lib/${legacyLib}:legacy-support
        configure.ldflags-delete        -Wl,${prefix}/lib/${legacyLib}
        configure.ldflags-append        -Wl,${prefix}/lib/${legacyLib}

        # Its headers too, for the C code that build scripts compile: e.g. TargetConditionals.h
        # defines TARGET_OS_OSX (missing before the 10.12 SDK; without it aws-lc-sys takes the iOS
        # CCRandomGenerateBytes path) and sys/random.h declares getentropy. As in the legacysupport
        # PG, use ${lang}_INCLUDE_PATH, which behaves like -isystem: compiler.cpath behaves like -I,
        # and legacy-support's GNU extensions warn under -pedantic (aws-lc's jitterentropy).
        foreach lang {C OBJC CPLUS OBJCPLUS} {
            rust::append_envs           ${lang}_INCLUDE_PATH=${prefix}/include/LegacySupport
        }
    }

    if {[string match "macports-clang*" [option configure.compiler]] && [option os.major] < 11} {
        # by default, ld64 uses ld64-127 when 9 <= ${os.major} < 11
        # Rust fails to build when architecture is x86_64 and ld64 uses ld64-127
        depends_build-delete            port:ld64-274
        depends_build-append            port:ld64-274
        depends_skip_archcheck-delete   ld64-274
        depends_skip_archcheck-append   ld64-274
        configure.ldflags-delete        -fuse-ld=${prefix}/bin/ld-274
        configure.ldflags-append        -fuse-ld=${prefix}/bin/ld-274
    }

    # rust-bootstrap requires `macosx_deployment_target` instead of `os.major`
    if {[option os.platform] eq "darwin" && [vercmp [option macosx_deployment_target] < 10.6]} {
        # __Unwind_RaiseException
        depends_lib-delete              port:libunwind
        depends_lib-append              port:libunwind
        configure.ldflags-delete        -lunwind
        configure.ldflags-append        -lunwind
    }

    post-extract {
        xinstall -d ${worksrcpath}/target/[cargo.rust_platform]/release
    }
}
port::register_callback rust::rust_pg_callback
