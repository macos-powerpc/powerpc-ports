# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4

# Copyright (c) 2015 The MacPorts Project
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
# Usage:
# PortGroup     locale_select 1.0

# provide a configurable variant to install only the translations (locale files) of interest
# the selection is made in ${prefix}/etc/macports/locales.tcl (which should really become locales.conf);
# a template is provided in `port dir K5rameworks` .
variant langselect description "prune translations from ${prefix}/share/locale, leaving only those\
                                specified in ${prefix}/etc/macports/locales.tcl" {}

# the prefix:
options langselect_prefix
default langselect_prefix       {${prefix}}
# optional directory (list) holding Qt translations (.qm) (fully specified)
# the _dir and _basename options can both be lists of identical length for projects
# that install translation files for multiple executables in as many individual dirs.
options langselect_qm_dir langselect_qm_basename
default langselect_qm_dir       {}
default langselect_qm_basename  {}
# optional directory (list) holding <lang>.html files
options langselect_html_dir
default langselect_html_dir     {}
# optional directory (list) holding <lang> directories
options langselect_dirs_dir
default langselect_dirs_dir     {}
# optional directory (list) holding *.lproj directories
options langselect_lproj_dir
default langselect_lproj_dir     {}

options langselect_keep_languages
default langselect_keep_languages {}

options langselect_keep_locales_file
default langselect_keep_locales_file {${prefix}/etc/macports/locales.tcl}

namespace eval langselect {

    set has_nonstandard_locations 0

    proc nonstandard_locations_handler {option action args} {
	   global langselect::has_nonstandard_locations
        if {${action} eq "set"} {
            set langselect::has_nonstandard_locations 1
        }
    }
    option_proc langselect_qm_dir langselect::nonstandard_locations_handler
    option_proc langselect_html_dir langselect::nonstandard_locations_handler
    option_proc langselect_dirs_dir langselect::nonstandard_locations_handler
    option_proc langselect_lproj_dir langselect::nonstandard_locations_handler

    proc check_against_basenames {fname} {
        global langselect_qm_basename
        foreach bn ${langselect_qm_basename} {
            if {[string match ${bn}* ${fname}]} {
                return 1
            }
        }
        return 0
    }

}

if {[variant_isset langselect]} {
    post-destroot {
        ui_debug "## starting langselect scan/pruning"
        if {[file exists ${langselect_keep_locales_file}] &&
            (${langselect::has_nonstandard_locations} || \
		  [file exists ${destroot}${langselect_prefix}/share/locale] || \
            [file exists [join ${langselect_qm_dir}]] || \
            [file exists ${destroot}${langselect_prefix}/share/man])
        } {
            ui_debug "Reading local locale prefs from \"${langselect_keep_locales_file}\""
            if {[catch {source "${langselect_keep_locales_file}"} err]} {
                ui_error "Error reading ${langselect_keep_locales_file}: $err"
                return -code error "Error reading ${langselect_keep_locales_file}"
            }
        }
        if {[info exists keep_languages]} {
            langselect_keep_languages ${keep_languages}
            foreach d [list ${destroot}${langselect_prefix}/share/locale ${destroot}${langselect_prefix}/share/doc/HTML ${destroot}${langselect_prefix}/share/man] {
                foreach l [glob -nocomplain ${d}/*] {
                    set lang [file tail ${l}]
                    if {[lsearch -exact ${keep_languages} ${lang}] eq "-1" && \
                        [string compare -length 3 ${lang} "man"] &&
                        [string compare -length 3 ${lang} "cat"]
                    } {
                        ui_info "rm ${l}"
                        file delete -force ${l}
                    } else {
                        ui_debug "won't delete ${l} (${lang})"
                    }
                }
            }
            set qmidx 0
            set wplen [string length ${workpath}]
            set drlen [string length ${destroot}]
            foreach ld ${langselect_qm_dir} {
                if {[string compare -length ${wplen} ${ld} ${workpath}]} {
                    set ld "${destroot}/${ld}"
                }
                ui_debug "locale checking ${ld}"
                foreach l [glob -nocomplain ${ld}/*.qm] {
                    set lang [file rootname [file tail ${l}]]
                    if {${langselect_qm_basename} ne {}} {
                        if {[llength ${langselect_qm_dir}] eq [llength ${langselect_qm_basename}]} {
                            set lang [string map [list "[lindex ${langselect_qm_basename} ${qmidx}]" ""] ${lang}]
                        } else {
                            set lang [string map [list "${langselect_qm_basename}" ""] ${lang}]
                        }
                    }
                    if {[lsearch -exact ${keep_languages} ${lang}] eq "-1"
                        && ![langselect::check_against_basenames ${lang}]} {
                        ui_info "rm ${l} (${lang})"
                        file delete -force ${l}
                    } else {
                        ui_debug "won't delete ${l} (${lang})"
                    }
                }
                set qmidx [expr ${qmidx} + 1]
            }
            foreach lhd ${langselect_html_dir} {
                # was this ever really necessary?
                set lhd [join ${lhd}]
                if {[string compare -length ${wplen} ${lhd} ${workpath}]} {
                    set lhd "${destroot}/${lhd}"
                }
                if {[file exists ${lhd}]} {
                    set lhtmldir ${lhd}
                    foreach l [glob -nocomplain ${lhtmldir}/*.html] {
                        set keep no
                        foreach lang ${keep_languages} {
                            if {[string match *${lang}.html ${l}]} {
                                set keep yes
                            }
                        }
                        if {[tbool keep]} {
                            ui_debug "won't delete ${l} (${lang})"
                        } else {
                            ui_info "rm ${l}"
                            file delete -force ${l}
                        }
                    }
                }
            }
            foreach ldd ${langselect_dirs_dir} {
                set ldd [join ${ldd}]
                if {[string compare -length ${wplen} ${ldd} ${workpath}]} {
                    set ldd "${destroot}/${ldd}"
                }
                if {[file exists ${ldd}]} {
                    set ldirdir ${ldd}
                    ui_debug "Pruning \"${ldirdir}\": [glob -nocomplain -types d ${ldirdir}/*]"
                    foreach l [glob -nocomplain -types d ${ldirdir}/*] {
                        set lang [file rootname [file tail ${l}]]
                        if {[lsearch -exact ${keep_languages} ${lang}] eq "-1"} {
                            ui_info "rm ${l}"
                            file delete -force ${l}
                        } else {
                            ui_debug "won't delete ${l} (${lang})"
                        }
                    }
                } elseif {${ldd} ne {}} {
                    ui_warn "Non-existent langselect_dirs_dir entry: \"${ldd}\""
                }
            }
            foreach lld ${langselect_lproj_dir} {
                set lld [join ${lld}]
                if {[string compare -length ${wplen} ${lld} ${workpath}]} {
                    set lld "${destroot}/${lld}"
                }
                if {[file exists ${lld}]} {
                    set ldirdir ${lld}
                    foreach l [glob -nocomplain -types d ${ldirdir}/*.lproj] {
                        set lang [file rootname [file tail ${l}]]
                        if {[lsearch -exact ${keep_languages} ${lang}] eq "-1"} {
                            ui_info "rm ${l}"
                            file delete -force ${l}
                        } else {
                            ui_debug "won't delete ${l} (${lang})"
                        }
                    }
                }
		  }
        } else {
            ui_debug "## langselect not applicable or configured - does ${langselect_keep_locales_file} exist?"
        }
        ui_debug "## langselect scan done."
    }
}

