#!/bin/bash

# Copyright (c) 2014 Stefan Jakobs <project AT localside.net>
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

STATFILE="/tmp/udp_stats.txt"
NOW="$(date +'%Y%m%d %H:%M:%S')"

read proto InDatagrams NoPorts InErrors OutDatagrams RcvbufErrors SndbufErrors <<< $(grep 'Udp:' /proc/net/snmp | tail -1 )

if [ -r "$STATFILE" ]; then
  read d t InDatagrams_s NoPorts_s InErrors_s OutDatagrams_s RcvbufErrors_s SndbufErrors_s <<< $(tail -1 "$STATFILE" )

   InDatagrams_d=$(( $InDatagrams - $InDatagrams_s ))
   NoPorts_d=$(( $NoPorts - $NoPorts_s ))
   InErrors_d=$(( $InErrors - $InErrors_s ))
   OutDatagrams_d=$(( $OutDatagrams - $OutDatagrams_s ))
   RcvbufErrors_d=$(( $RcvbufErrors - $RcvbufErrors_s ))
   SndbufErrors_d=$(( $SndbufErrors - $SndbufErrors_s ))
fi
echo "$NOW: $InDatagrams $NoPorts $InErrors $OutDatagrams $RcvbufErrors $SndbufErrors" >> $STATFILE

if [ "${InErrors_d:-0}" -gt 0 ]; then
   echo "$NOW - total UDP errors changed"
   echo "InDatagrams: $InDatagrams_d"
   echo "NoPorts: $NoPorts_d"
   echo "InErrors: $InErrors_d"
   echo "OutDatagrams: $OutDatagrams_d"
   echo "RcvbufErrors: $RcvbufErrors_d"
   echo "SndbufErrors: $SndbufErrors_d"
fi
