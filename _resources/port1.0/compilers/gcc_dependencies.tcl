# set library dependencies of  GCC compilers to the variable libgccs based on gcc_version

# GCC version providing the primary runtime
# Note settings here *must* match those in the lang/libgcc port and compilers PG
set gcc_main_version 14

# compiler links against libraries in libgcc\d* and/or libgcc-*
if {[vercmp ${gcc_version} 4.6] < 0} {
    set libgccs [list path:share/doc/libgcc/README:libgcc port:libgcc45]
} elseif {[vercmp ${gcc_version} 7] < 0} {
    set libgccs [list path:share/doc/libgcc/README:libgcc port:libgcc6]
} elseif {[vercmp ${gcc_version} ${gcc_main_version}] < 0} {
    set libgccs [list path:share/doc/libgcc/README:libgcc port:libgcc${gcc_version}]
} else {
    # Using primary GCC version
    # Do not depend directly on primary runtime port, as implied by libgcc
    # and doing so prevents libgcc-* being used as an alternative.
    set libgccs [list path:share/doc/libgcc/README:libgcc]
}
