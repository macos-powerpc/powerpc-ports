#!/bin/sh

QPSs="`qtpaths -qt=qt5 --types`"

# remove any trailing / from TMPDIR:
TMPDIR="`echo ${TMPDIR} | sed -e 's|/$||g'`"

print_QSPs () {
	for l in ${QPSs} ;do
		echo "${l} = `qtpaths $@ ${l}`" | \
			sed -e "s|${HOME}|\$HOME|g" -e "s|${TMPDIR}|\$TMPDIR|g"
	done
}

echo
echo "Standard locations:"
echo

print_QSPs --paths

echo
echo "Standard locations, testing mode:"
echo

print_QSPs --testmode --paths

echo
echo "Writable locations:"
echo

print_QSPs --writable-path

echo
echo "Writable locations, testing mode:"
echo

print_QSPs --testmode --writable-path

echo
echo "Standard locations, XDG/Freedesktop compliant mode:"
echo

print_QSPs --xdgmode --paths

echo
echo "Standard locations, testing + XDG/Freedesktop compliant mode:"
echo

print_QSPs --testmode --xdgmode --paths

echo
echo "Writable locations, XDG/Freedesktop compliant mode:"
echo

print_QSPs --xdgmode --writable-path

echo
echo "Writable locations, testing + XDG/Freedesktop compliant mode:"
echo

print_QSPs --testmode --xdgmode --writable-path
