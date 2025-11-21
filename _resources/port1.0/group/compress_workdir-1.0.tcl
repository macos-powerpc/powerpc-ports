# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4

# Copyright (c) 2015 The MacPorts Project
# Copyright (c) 2016 R.J.V. Bertin
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
# PortGroup     compress_workdir 1.0
#

if {[info exists compress_workdir::currentportgroupdir]} {
    ui_debug "[dict get [info frame 0] file] has already been loaded"
    return
}

namespace eval compress_workdir {
    # our directory:
    variable currentportgroupdir [file dirname [dict get [info frame 0] file]]
}

proc compress_workdir::build_dirs {} {
    global build.dir
    return [glob -nocomplain -type d ${build.dir}*]
}

options compress.build_dir \
        compress.in_applications_dir
default compress.build_dir {[compress_workdir::build_dirs]}
default compress.in_applications_dir {}

platform darwin {
    # sadly we cannot rely on [file system <name>] to determine if we're on a
    # filesystem supporting HFS compression so we need to rely on the user.
    if {[info exist ::env(MACPORTS_COMPRESS_WORKDIR)] && $::env(MACPORTS_COMPRESS_WORKDIR)} {

        # Enable HFS compression if bsdtar is already installed
        if {[file exists ${prefix}/bin/bsdtar]} {
            extract.post_args    "| ${prefix}/bin/bsdtar -x --hfsCompression"
        }

        proc hfscompress {target} {
            global use_parallel_build build.jobs prefix
            # from RJVB's "Base" tweaks:
            catch {flush_logfile}
            if {${use_parallel_build}} {
                set compjobs "-J${build.jobs}"
            } else {
                set compjobs ""
            }
            # first try compressing in parallel, without backups/verification (this is all "redundant" data)
            if {[catch {system "${prefix}/bin/afsctool -cfvv -8 ${compjobs} -S -L -n ${target}/ 2>&1"} result context]} {
                ui_info "Compression failed: ${result}, ${context}; port:afsctool is probably installed without support for parallel compression"
                if {[catch {system "${prefix}/bin/afsctool -cfvv -8 ${target}/ 2>&1"} result context]} {
                    ui_error "Compression failed: ${result}, ${context}"
                    return -code error "Compression failed"
                } else {
                    ui_debug "Compressed ${target}: ${result}"
                }
            } else {
                ui_debug "Compressed ${target}: ${result}"
            }
            return 1
        }

        proc hfscompress_bg {target} {
            global use_parallel_build build.jobs prefix
            catch {flush_logfile}
            if {${use_parallel_build}} {
                set compjobs "-J${build.jobs}"
            } else {
                set compjobs ""
            }
            # first try compressing in parallel, without backups/verification (this is all "redundant" data)
            if {[catch {set outfile [get_logfile]} err]} {
                set outfile "/dev/null"
            } else {
                set outfile "${outfile}.[file tail ${target}]"
                ui_debug "sending background afsctool output to \"${outfile}\""
            }
            if {[catch {exec sh -c "${prefix}/bin/afsctool -cfvv -8 ${compjobs} -S -L -n ${target}/ 2>&1 ; exit 0" >& ${outfile} &} result context]} {
                ui_info "Compression failed: ${result}, ${context}; port:afsctool is probably installed without support for parallel compression"
                hfscompress ${target}
            } else {
                ui_debug "Compressing ${target}: pid ${result}"
            }
            return 1
        }

        post-extract {
            if {[file exists ${prefix}/bin/afsctool]} {
                ui_debug "--->  Compressing the source directory once more..."
                catch {hfscompress ${worksrcpath}}
                if {[info exists rustup::home]} {
                    ui_msg "---> Compressing the rustup install directory ${rustup::home}"
                    catch {hfscompress_bg ${rustup::home}}
                }
            }
        }

        proc compress_workdir::callback {} {
            global prefix compress.build_dir worksrcpath configure.ccache destroot compress.in_applications_dir
            global workpath
            post-build {
                if {[file exists ${prefix}/bin/afsctool]} {
                    ui_msg "--->  Compressing the build directory ..."
                    catch {flush_logfile}
                    if {${compress.build_dir} ne "${worksrcpath}"} {
                        set compress.build_dir "${worksrcpath} ${compress.build_dir}"
                    }
                    if {![catch {hfscompress ${compress.build_dir}} result context]} {
                        set extradirs "${workpath}/.home ${workpath}/.tmp"
                        if {[info exists rustup::home] && [file exists ${rustup::home}]} {
                            set extradirs "${extradirs} ${rustup::home}"
                        }
                        if {[file exists ${workpath}/cargo-cache]} {
                            set extradirs "${extradirs} ${workpath}/cargo-cache"
                        }
                        ui_msg "--->  Compressing additional directories [string map [list ${workpath}/ ""] ${extradirs}] ..."
                        catch {flush_logfile}
                        catch {hfscompress ${extradirs}}
                    }
                }
            }
            post-destroot {
                if {[file exists ${prefix}/bin/afsctool]} {
                    if {[tbool configure.ccache]} {
                        ui_msg "--->  Compressing the ccache directory ..."
                        catch {flush_logfile}
                        catch {hfscompress_bg ${ccache_dir}}
                    }
                    set destroots [glob -nocomplain -type d ${destroot}-*]
                    if {${destroots} ne {}} {
                        ui_msg "--->  Compressing auxiliary destroot dirs ..."
                        catch {flush_logfile}
                        catch {hfscompress ${destroots}}
                    }
                }
            }
            post-activate {
                if {[option compress.in_applications_dir] ne {}} {
                    ui_msg "--->  Compressing ${compress.in_applications_dir} ..."
                    catch {flush_logfile}
                    catch {hfscompress ${compress.in_applications_dir}}
                }
            }
        }

        port::register_callback compress_workdir::callback
    }

}
