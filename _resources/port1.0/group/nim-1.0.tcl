# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4

# This PortGroup provides support for building Nim packages.
#
# Usage:
#
# For GitHub-hosted packages:
#   PortSystem      1.0
#   PortGroup       nim 1.0
#   nim.setup       github <author> <repo> <version> [tag_prefix]
#
# For other sources:
#   PortSystem      1.0
#   PortGroup       nim 1.0
#   nim.setup       <package> <version>
#
# Options:
#
#   nim.setup github <author> <repo> <version> [tag_prefix]
#       Set up a Nim package hosted on GitHub.
#       Automatically includes and configures the GitHub portgroup.
#
#       <repo> should be the actual GitHub repository name (e.g., "nim-regex" or "regex").
#       The portgroup automatically strips the "nim-" prefix if present to determine
#       the package name. The port name will always be "nim-<package>".
#
#       If the package name differs from the repository name (e.g., repo has hyphens),
#       set nim.package_name explicitly after nim.setup.
#
#   nim.setup <package> <version>
#       Set up a Nim package from other sources.
#       The port name will be "nim-<package>".
#       You must configure master_sites and distname yourself.
#
#   nim.build_type
#       Specifies the build mechanism to use. Possible values:
#           nimble  - Use nimble to build and install (default)
#           nim     - Use nim compiler directly
#           custom  - Custom build/destroot (port provides its own)
#
#   nim.build_flags
#       Additional flags to pass to nim compiler (e.g., -d:release, --threads:on)
#       Default: -d:release
#
#   nim.install_binaries
#       List of binary names to install from the build directory
#       Only used when nim.build_type is 'nim'
#
#   nim.nimble_binaries
#       List of binary names to install for nimble-built applications
#       When set, prevents 'nimble install' from running (avoids rebuild)
#
#       - For applications: Set to binary names (e.g., {moe})
#       - For libraries: Leave empty
#
#       When empty, portgroup installs package files to:
#           ${prefix}/lib/nimble/pkgs2/${nim.package_name}/
#
#   nim.cc_backend
#       C compiler backend to use. Possible values:
#           gcc     - Use GCC (default for older systems)
#           clang   - Use Clang
#           auto    - Auto-detect based on configure.compiler
#
#   nim.setup_cc
#       Enable automatic C compiler setup (default: yes)
#       When enabled, creates gcc symlink workaround for Nim
#
#   nim.vcs_revision
#       Git commit hash/revision for nimblemeta.json (default: 40 zeros)
#       Can be set in portfile to track exact source revision
#
#   nim.url
#       Repository URL for nimblemeta.json
#       Automatically set for GitHub packages via nim.setup
#       Can be overridden for non-GitHub packages.

PortGroup               compilers 1.0

options nim.build_type
default nim.build_type  {nimble}

options nim.build_flags
default nim.build_flags {-d:release}

options nim.install_binaries
default nim.install_binaries {}

# For nimble builds: specify binaries to install instead of using nimble install.
# This prevents rebuilding during destroot.
options nim.nimble_binaries
default nim.nimble_binaries {}

options nim.bin
default nim.bin     {${prefix}/bin/nim}

options nim.nimble
default nim.nimble  {${prefix}/bin/nimble}

# Note: Nimble automatically adds pkgs2/ subdirectory, so we don't include it here.
set nim.pkgsdir     ${prefix}/lib/nimble
set nim.bindir      ${prefix}/lib/nimble/bin

options nim.parallel_build
default nim.parallel_build {yes}

options nim.cc_backend
default nim.cc_backend {auto}

options nim.setup_cc
default nim.setup_cc {yes}

options nim.compiler_flags
default nim.compiler_flags {}

# Track the package name (without nim- prefix)
options nim.package_name
default nim.package_name {}

# Track package metadata for nimblemeta.json
options nim.url
default nim.url {}

options nim.vcs_revision
# Lazy default to write something into metadata:
default nim.vcs_revision {0000000000000000000000000000000000000000}

# Set C standard to C11 (matches Nim's requirements)
compiler.c_standard 2011

# Setup procedure for Nim packages
# Usage: nim.setup [github] <author> <package> <version> [tag_prefix]
#   or:  nim.setup <package> <version>
proc nim.setup {args} {
    global name version
    global nim.build_type
    global nim.package_name
    global nim.url

    set argc [llength ${args}]

    # Check if first argument is "github"
    if {[lindex ${args} 0] eq "github"} {
        # GitHub setup: nim.setup github <author> <package> <version> [tag_prefix]
        if {${argc} < 4 || ${argc} > 5} {
            return -code error "nim.setup github requires 3-4 arguments: <author> <package> <version> \[tag_prefix\]"
        }

        set author      [lindex ${args} 1]
        set repo_name   [lindex ${args} 2]
        set pkg_version [lindex ${args} 3]
        set tag_prefix  [expr {${argc} == 5 ? [lindex ${args} 4] : ""}]

        # Strip nim- prefix from repo name if present (for package name)
        # GitHub repos may be named "nim-foo" or just "foo"
        if {[string match "nim-*" ${repo_name}]} {
            set package [string range ${repo_name} 4 end]
        } else {
            set package ${repo_name}
        }

        # Include GitHub portgroup dynamically
        uplevel 1 "PortGroup github 1.0"

        # Configure GitHub setup with the actual repo name (may include nim- prefix)
        uplevel 1 "github.setup ${author} ${repo_name} ${pkg_version} ${tag_prefix}"

        uplevel 1 "github.tarball_from archive"

        # Set nim-specific variables: port name always has nim- prefix.
        name                nim-${package}
        version             ${pkg_version}
        nim.package_name    ${package}
        nim.url             https://github.com/${author}/${repo_name}

    } else {
        # Simple setup: nim.setup <package> <version>
        if {${argc} != 2} {
            return -code error "nim.setup requires either 'github <author> <package> <version> \[tag_prefix\]' or '<package> <version>'"
        }

        set package     [lindex ${args} 0]
        set pkg_version [lindex ${args} 1]

        name                nim-${package}
        version             ${pkg_version}
        nim.package_name    ${package}
    }

    categories              nim

    depends_build-append    port:nim \
                            port:nimble

    depends_lib-append      port:nim

    use_configure           no
}

# Procedure to determine C compiler backend for Nim
proc nim.get_cc_backend {} {
    global nim.cc_backend configure.compiler

    if {${nim.cc_backend} ne "auto"} {
        return ${nim.cc_backend}
    }

    # Auto-detect based on configure.compiler
    if {[string match "clang*" ${configure.compiler}] ||
        [string match "macports-clang*" ${configure.compiler}]} {
        return "clang"
    } elseif {[string match "*gcc*" ${configure.compiler}]} {
        return "gcc"
    }
}

# Procedure to get C compiler executable name
proc nim.get_cc_exe {} {
    global configure.cc

    # Extract just the executable name from the full path
    if {[string match clang-mp-* ${configure.cc}]} {
        set clang_v [
            string range ${configure.cc} [
                string length clang-mp-
            ] end
        ]
        return clang-mp-${clang_v}
    } elseif {[string match gcc-mp-* ${configure.cc}]} {
        set gcc_v [
            string range ${configure.compiler} [
                string length macports-gcc-
            ] end
        ]
        return gcc-mp-${gcc_v}
    } else {
        return [file tail ${configure.cc}]
    }
}

# Procedure to get C compiler path
proc nim.get_cc_path {} {
    global configure.cc prefix

    # Get the directory containing the compiler
    set cc_dir [file dirname ${configure.cc}]

    # If it's a MacPorts compiler, return the bin directory
    if {[string match "${prefix}/*" ${configure.cc}]} {
        return ${prefix}/bin
    }

    return ${cc_dir}
}

# Procedure to generate Nim compiler flags for C backend
proc nim.get_compiler_flags {} {
    global nim.compiler_flags prefix configure.cxx_stdlib os.platform

    set cc_backend [nim.get_cc_backend]
    set cc_exe [nim.get_cc_exe]
    set cc_path [nim.get_cc_path]

    set flags [list]

    # Add the C compiler backend
    lappend flags "--cc:${cc_backend}"

    # Add the compiler path and executable
    lappend flags "--${cc_backend}.path:${cc_path}"
    lappend flags "--${cc_backend}.exe:${cc_exe}"
    lappend flags "--${cc_backend}.linkerexe:${cc_exe}"

    # This helps Nim find MacPorts libraries (ncurses, pcre, openssl etc.)
    lappend flags "--passC:-I${prefix}/include"
    lappend flags "--passL:-L${prefix}/lib"

    # Add rpath so runtime loader finds MacPorts libraries
    # This prevents conflicts with system libraries (libarchive, libiconv etc.)
    if {${os.platform} eq "darwin" && ${configure.cxx_stdlib} ne "libc++"} {
        lappend flags "--passL:-Wl,-rpath,${prefix}/lib/libgcc,-rpath,${prefix}/lib"
    } else {
        lappend flags "--passL:-Wl,-rpath,${prefix}/lib"
    }

    # Add any custom compiler flags
    foreach flag ${nim.compiler_flags} {
        lappend flags ${flag}
    }

    return ${flags}
}

# Procedure to set up build arguments
proc nim.configure_build {} {
    global nim.build_flags nim.parallel_build nim.setup_cc build.jobs

    set build_args [list]

    # Add compiler flags if CC setup is enabled
    if {${nim.setup_cc}} {
        set build_args [concat ${build_args} [nim.get_compiler_flags]]
    }

    # Add build flags
    foreach flag ${nim.build_flags} {
        lappend build_args ${flag}
    }

    # Add parallel build flag if enabled
    if {${nim.parallel_build}} {
        lappend build_args "--parallelBuild:${build.jobs}"
    }

    return ${build_args}
}

# Post-extract: Set up C compiler symlink for Nim
# Nim doesn't respect standard CC environment variables, so we create
# a gcc/clang symlink in a local bin directory that Nim can find
post-extract {
    global nim.setup_cc worksrcpath configure.cc

    if {${nim.setup_cc}} {
        # Create a local bin directory
        file mkdir ${worksrcpath}/bin

        # Determine the symlink name based on compiler backend
        set cc_backend [nim.get_cc_backend]
        if {${cc_backend} eq "gcc"} {
            set link_name "gcc"
        } else {
            set link_name "clang"
        }

        # Create symlink to the actual compiler
        ln -sf ${configure.cc} ${worksrcpath}/bin/${link_name}

        # Also create generic cc link
        ln -sf ${configure.cc} ${worksrcpath}/bin/cc
    }
}

# Default build phase for nimble-based builds
default build.cmd       {${nim.nimble}}
default build.target    {build}

# Configure build phase based on build type
pre-build {
    global nim.build_type nim.setup_cc nim.nimble_binaries prefix

    # Create a nimcache directory to avoid clutter
    file mkdir ${workpath}/.nimcache

    # Prepend local bin to PATH if CC setup is enabled
    if {${nim.setup_cc}} {
        set env(PATH) "${worksrcpath}/bin:$env(PATH)"
    }

    if {${nim.build_type} eq "nimble"} {
        # Check if this is a library (no binaries) or application:
        if {[llength ${nim.nimble_binaries}] == 0} {
            # Library package - no build needed, just source files, which are arch-independent.
            supported_archs noarch
            build.cmd       /usr/bin/true
            build.target    {}
            build.args      {}
        } else {
            # Application package - build with Nim compiler directly.
            # Create pkg/ directory for Nimble-style imports (import pkg/foo).

            ui_info "Creating pkg/ directory at ${worksrcpath}/pkg"
            file mkdir ${worksrcpath}/pkg

            # Symlink all MacPorts packages into pkg/ directory
            set nim_paths [list]
            if {[file exists ${prefix}/lib/nimble/pkgs2]} {
                ui_info "Symlinking packages from ${prefix}/lib/nimble/pkgs2"
                foreach pkgdir [glob -nocomplain -directory ${prefix}/lib/nimble/pkgs2 -type d *] {
                    set pkgname [file tail ${pkgdir}]
                    set linkpath ${worksrcpath}/pkg/${pkgname}
                    ui_debug "Linking ${pkgname}: ${pkgdir} -> ${linkpath}"
                    # Delete any existing link/file first
                    if {[file exists ${linkpath}]} {
                        file delete -force ${linkpath}
                    }
                    file link -symbolic ${linkpath} ${pkgdir}
                    lappend nim_paths "--path:${pkgdir}"

                    # If package has a src/ subdirectory, also add that to the path.
                    # This is needed for packages like parsetoml that have src/parsetoml.nim
                    if {[file isdirectory ${pkgdir}/src]} {
                        lappend nim_paths "--path:${pkgdir}/src"
                    }
                }
            } else {
                ui_warn "No packages found at ${prefix}/lib/nimble/pkgs2"
            }

            # Find main source file - check common locations:
            set main_file ""
            foreach candidate [list \
                ${worksrcpath}/src/${nim.package_name}.nim \
                ${worksrcpath}/${nim.package_name}.nim \
                ${worksrcpath}/src/main.nim] {
                if {[file exists ${candidate}]} {
                    set main_file ${candidate}
                    break
                }
            }

            if {${main_file} eq ""} {
                ui_error "Could not find main source file for ${nim.package_name}"
                return -code error "No main .nim file found"
            }

            build.cmd       ${nim.bin}
            build.target    {}
            # Compile directly, passing paths to all MacPorts packages
            # IMPORTANT: Add worksrcpath so nim can find the pkg/ directory we created
            build.args      c \
                            --noNimblePath \
                            --path:${worksrcpath} \
                            {*}${nim_paths} \
                            --nimcache:${workpath}/.nimcache \
                            {*}[nim.configure_build] \
                            ${main_file}
        }
    } elseif {${nim.build_type} eq "nim"} {
        # Build using nim compiler directly
        build.cmd       ${nim.bin}
        build.target    c
        build.args      --nimcache:${workpath}/.nimcache \
                        --noNimblePath \
                        {*}[nim.configure_build]
    }
}

# Default destroot phase - disable for manual installation
default destroot.cmd    {/usr/bin/true}
default destroot.target {}
default destroot.args   {}
default destroot.destdir {}

# Configure destroot phase based on build type.
pre-destroot {
    global nim.build_type nim.install_binaries nim.nimble_binaries nim.pkgsdir destroot prefix worksrcpath

    # Create necessary directories:
    file mkdir ${destroot}${prefix}/bin
    file mkdir ${destroot}${nim.pkgsdir}/pkgs2
}

# Post-destroot: Install binaries from build directory or package files for libraries.
post-destroot {
    global nim.build_type nim.install_binaries nim.nimble_binaries nim.package_name nim.pkgsdir destroot prefix worksrcpath

    # Handle binary installation for both nim and nimble build types.
    set binaries_to_install {}

    if {${nim.build_type} eq "nim" && [llength ${nim.install_binaries}] > 0} {
        set binaries_to_install ${nim.install_binaries}
    } elseif {${nim.build_type} eq "nimble" && [llength ${nim.nimble_binaries}] > 0} {
        set binaries_to_install ${nim.nimble_binaries}
    }

    if {[llength ${binaries_to_install}] > 0} {
        # Application: install binaries
        xinstall -d -m 0755 ${destroot}${prefix}/bin
        foreach binary ${binaries_to_install} {
            # Try to find the binary in common locations
            set binary_path ""
            foreach searchpath [list ${worksrcpath} ${worksrcpath}/src ${worksrcpath}/bin] {
                if {[file exists ${searchpath}/${binary}] && [file isfile ${searchpath}/${binary}]} {
                    set binary_path ${searchpath}/${binary}
                    break
                }
            }

            if {${binary_path} ne ""} {
                xinstall -m 0755 ${binary_path} ${destroot}${prefix}/bin/
            } else {
                ui_warn "Could not find binary file: ${binary}"
            }
        }
    } elseif {${nim.build_type} eq "nimble" && [llength ${nim.nimble_binaries}] == 0} {
        # Library: install package files to shared directory.
        set pkg_destdir ${destroot}${nim.pkgsdir}/pkgs2/${nim.package_name}
        xinstall -d -m 0755 ${pkg_destdir}

        # Find and copy the .nimble file:
        set nimble_file ""
        foreach f [glob -nocomplain -directory ${worksrcpath} *.nimble] {
            set nimble_file ${f}
            break
        }
        if {${nimble_file} ne ""} {
            xinstall -m 0644 ${nimble_file} ${pkg_destdir}/
        } else {
            ui_warn "No .nimble file found for package ${nim.package_name}"
        }

        # Copy all .nim source files and directories.
        # This preserves the package structure.
        foreach item [glob -nocomplain -directory ${worksrcpath} *] {
            set itemname [file tail ${item}]

            # Skip non-package files/directories:
            if {${itemname} in {tests examples docs .git .github}} {
                continue
            }

            if {[file isdirectory ${item}]} {
                # Special case: always copy src/ directory if it exists.
                # Packages like nim-sat have nested structure (src/sat/sat.nim)
                if {${itemname} eq "src"} {
                    copy ${item} ${pkg_destdir}/
                    ui_debug "Copied src/ directory for ${nim.package_name}"
                } elseif {${itemname} eq ${nim.package_name}} {
                    copy ${item} ${pkg_destdir}/
                    ui_debug "Copied ${itemname}/ directory for ${nim.package_name}"
                } elseif {[llength [glob -nocomplain -directory ${item} -type f *.nim]] > 0 ||
                          [llength [glob -nocomplain -directory ${item} -type f *.nims]] > 0} {
                    # Check if directory contains .nim files directly.
                    # Copy entire directory:
                    copy ${item} ${pkg_destdir}/
                }
            } elseif {[file extension ${item}] in {.nim .nims}} {
                # Copy individual .nim/.nims files:
                xinstall -m 0644 ${item} ${pkg_destdir}/
            }
        }

        # Generate nimblemeta.json for the package.
        # This is required for Nimble to recognize the package.
        set metadata_json "{\n"
        append metadata_json "  \"version\": 1,\n"
        append metadata_json "  \"metaData\": {\n"
        append metadata_json "    \"url\": \"${nim.url}\",\n"
        append metadata_json "    \"downloadMethod\": \"git\",\n"
        append metadata_json "    \"vcsRevision\": \"${nim.vcs_revision}\",\n"
        append metadata_json "    \"files\": \[\],\n"
        append metadata_json "    \"binaries\": \[\],\n"
        append metadata_json "    \"specialVersions\": \[\"${version}\"\]\n"
        append metadata_json "  }\n"
        append metadata_json "}\n"

        set metadata_file [open ${pkg_destdir}/nimblemeta.json w]
        puts -nonewline ${metadata_file} ${metadata_json}
        close ${metadata_file}

        ui_info "${nim.package_name} package will be installed to: ${nim.pkgsdir}/pkgs2/${nim.package_name}"
    }
}

# FIXME: Nimble is designed not to care about what a developer or user needs.
# Normal builds are a pain to configure properly, and tests are a nightmare.
# By default we just disable them.
# Running tests currently requires to deactivate all nim-* packages; Nimble will fetch
# bundled dependencies instead. This may break, generate incorrect objects, etc.
# It is not advisable to allow installing anything from builds with tests.
# An ugly example of how tests can actually run can be found in nim-bearssl port.
pre-test {
    global test.args worksrcpath workpath env nim.setup_cc

    # Prepend local bin to PATH if CC setup is enabled
    if {${nim.setup_cc}} {
        set env(PATH) "${worksrcpath}/bin:$env(PATH)"
    }

    # Create a local nim.cfg that prevents reading the system config
    # The global nim.cfg at /opt/local/libexec/nim/config/nim.cfg has --path entries
    # that interfere with nimble's parsing of .nimble files as NimScript
    # Nim reads configs in order: current dir -> parents -> user -> system
    # So a local nim.cfg with --skipParentCfg will prevent system config from being read
    set local_nim_cfg ${worksrcpath}/nim.cfg
    set fp [open ${local_nim_cfg} w]
    puts ${fp} "# Local nim.cfg for tests - prevent system config interference"
    puts ${fp} "--skipParentCfg"
    close ${fp}
    ui_info "Created local nim.cfg at ${worksrcpath}/nim.cfg with --skipParentCfg"

    # Configure nimble test with auto-accept prompts and verbose output
    # Allow nimble to download test dependencies - they stay in work directory
    test.args --accept --verbose
}

# Test support - disabled by default (can be enabled per-port)
default test.run            no
default test.cmd            {${nim.nimble}}
default test.target         test
default test.args           {}
