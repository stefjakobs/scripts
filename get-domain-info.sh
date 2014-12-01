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

# Beschreibung
#
# Das Skript fragt die DNS MX-records ab, gibt diese aus und
# fragt die transport table auf vmr1 ($TRANSPORT_ON_HOST) nach
# weiteren Zielen ab. Das Ergebnis wird ausgegeben.
#
#####################################################################

TRANSPORT_ON_HOST=mx.example.com
TRANSPORT_PATH=/etc/postfix/transport

usage() {
   echo "usage: $0 <fqdn>"
   exit 1
}

# Überprüfe, ob wir einen Parameter haben
if [ -z $1 ]; then 
   usage;
else
   fqdn="$1"
fi

# check for dig
if ! DIG=$(which dig 2> /dev/null); then
   echo "dig ist nicht installiert!"
   exit 1
fi

A_RECORD=$($DIG +short -t a $fqdn &)
AAAA_RECORD=$($DIG +short -t aaaa $fqdn &)
MX_RECORD_FULL=$($DIG +short -t mx $fqdn &)
wait
MX_RECORD=$(while read line; do echo $line | cut -d" " -f2; done <<< "$MX_RECORD_FULL")

echo
echo    "Domain:       $fqdn"
echo -n "--------------"
echo "$fqdn" | tr [:graph:] '-'
if [ -n "$A_RECORD" ]; then
   echo "A-record(s):"
   while read line; do echo "  - $line"; done <<< "$A_RECORD"
fi
if [ -n "$AAAA_RECORD" ]; then
   echo "AAAA-record(s):"
   while read line; do echo "  - $line"; done <<< "$AAAA_RECORD"
fi
if [ -n "$MX_RECORD_FULL" ]; then
   echo "MX-record(s):"
   while read line; do echo "  - $line"; done <<< "$MX_RECORD_FULL"
fi

NEXTHOPS="$(ssh $TRANSPORT_ON_HOST "egrep '(^|^\.)${fqdn}' ${TRANSPORT_PATH} | grep -v ^#")"
if [ -n "$NEXTHOPS" ] || [ -n "$MX_RECORD" ]; then
   echo "Mail routing:"
   if [ -n "$MX_RECORD" ]; then
      echo -n "  * -> " 
      declare counter=0
      while read line; do
         if (( $counter == 0 )); then
            echo -n $line
            counter=$counter+1
         else
            echo -en "\n       $line"
         fi
      done <<< "$MX_RECORD"
   fi
fi
if [ -n "$NEXTHOPS" ]; then
   echo " -> $(echo "$NEXTHOPS" | grep "^$fqdn" | cut -d: -f2)"
   OTHER_NEXTHOPS="$(echo "$NEXTHOPS" | grep -v "^$" | egrep '^\.')"
fi
if [ -n "$OTHER_NEXTHOPS" ]; then
   echo
   echo "Other nexthops:"
   echo "$OTHER_NEXTHOPS"
fi
echo
echo
