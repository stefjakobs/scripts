#!/bin/bash

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

# Beschreibung:
# Gebe aus, wem ein Absender alles eine E-Mail zugestellt hat. Oder
# gebe aus, von wem ein Empfänger alles eine E-Mail zugestellt hat.

TO=''
FROM=''

function usage {
   echo "usage: $0 -to|-from email@example.com /path/to/postfix.log"
   echo
   exit 1
}

function exgrep {
   if [[ "$@" =~ (\.gz$) ]]; then
      zegrep $@
   else
      egrep $@
   fi
}

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
   usage
fi

if [ "$1" = '-to' ]; then
  RESULT='from'
  SOURCE='to'
elif [ "$1" = '-from' ]; then
  RESULT='to'
  SOURCE='from'
else
  usage
fi

MAIL_ADDR="$2"   # Absender/Empfänger ohne <..>
shift 2
LOG="$@"         # Postfix logfile

for curLog in $LOG; do
   echo "process logfile: $curLog"
   while read qid; do 
      exgrep $qid $curLog | grep "${RESULT}=" | awk '{ print $7 }' | cut -d= -f2 | grep -v 'END-OF-MESSAGE'
   done <<< "$(exgrep "${SOURCE}=<${MAIL_ADDR}>" $curLog | egrep -v "NOQUEUE|END-OF-MESSAGE" | awk '{print $6 }')"
done
