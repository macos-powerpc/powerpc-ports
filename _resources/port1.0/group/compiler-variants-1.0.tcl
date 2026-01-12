# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4

if {![info exists LTO::load_compvars] || !${LTO::load_compvars}} {
	return -code error "The compiler-variants PG should only be loaded by the LTO PG!"
}

namespace eval compvars {}

# a list of known compilers for which we provide a non-automatic placeholder variant to label installs with
# These are the names of the C compilers, with the dashes (-) replaced by underscores.
#
# "Known" means a compiler that I use or have used; requests can be made to add others.
#
set compvars::known_compilers { \
    clang \
    clang_mp_5.0 \
    clang_mp_6.0 \
    clang_mp_7.0 \
    clang_mp_8.0 \
    clang_mp_9.0 \
    clang_mp_10 \
    clang_mp_11 \
    clang_mp_12 \
    clang_mp_13 \
    clang_mp_14 \
    clang_mp_15 \
    clang_mp_16 \
    clang_mp_17 \
    gcc_mp_7 \
    gcc_mp_12 \
    gcc_mp_13 \
    gcc_mp_14 \
}

foreach comp ${compvars::known_compilers} {
    if {![variant_exists ${comp}]} {
        set confs {}
        foreach c2 ${compvars::known_compilers} {
            if {${c2} ne ${comp}} {
                lappend confs ${c2}
            }
        }
        variant ${comp} requires builtwith conflicts ${confs} description "placeholder variant to record the compiler used" {}
    }
}
pre-configure {
    foreach comp ${compvars::known_compilers} {
        if {[variant_isset ${comp}]} {
            ui_warn "+builtwith+${comp} are just placeholder variants used only to label the install with the compiler used"
        }
    }
}
