#!/usr/bin/env bash

# chdir to the port directory
cd `dirname $0`
PORT=`port -q info --name`
PORTDIR=`basename ${PWD}`
cd ..
CATDIR=`basename ${PWD}`
cd ..

EXTRAFILES="_resources/port1.0/group/qt5*-1.0.tcl _resources/port1.0/group/qmake5*-1.0.tcl _resources/port1.0/group/macports_clang_selection-1.0.tcl _resources/port1.0/group/locale_select-1.0.tcl "

# echo ${PORT} ${CATDIR} ${PORTDIR}
tar -cvjf ${PORT}.tar.bz2 ${EXTRAFILES} ${CATDIR}/${PORTDIR} 
ll -h ${PORT}.tar.bz2
