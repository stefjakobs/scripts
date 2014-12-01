#!/bin/sh

# Copyright (c) 2014 Stefan Jakobs <projects AT localside.net>
#####################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
######################################################################

# Beschreibung
# Das Skript erwartet ein OpenOffice Dokument als Parameter, und
# entpackt dieses in ein temporäres Verzeichnis. Anschließend werden
# die XML tags aus der Inhaltsdatei entfernt und der restliche Inhalt
# über less angezeigt. Schließlich löscht das Skript das temporäre 
# Verzeichnis.

if [ -z $1 ]; then
   echo "usage: $0 <file.odt>"
   exit 1
elif ! [ -r $1 ]; then
   echo "error: can not read $1!"
   exit 1
fi

TMPDIR=$(mktemp -d)
unzip -d $TMPDIR $1 >/dev/null

if [ -r $TMPDIR/content.xml ]; then
   perl -p -e "s/<[^>]*>/ /g;s/\n/ /g;s/ +/ /;" < $TMPDIR/content.xml | ${PAGER:-less}
fi

rm -r $TMPDIR
