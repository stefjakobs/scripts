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
# Überprüft, ob ein Benutzeraccount abgelaufen ist und gibt eine
# entsprechende Meldung aus.

now=$(date +%s)
retval=0
first=1
interval=$(( 7*24*60*60 ))  # 7 days

PATH=/bin/:/usr/bin/:$PATH
LANG=C

function run_only_once() {
   if [ $first -eq 1 ]; then
      echo "Die folgenden Accounts auf *${HOSTNAME}* sind abgelaufen:"
      echo
      first=0
   fi
}

# lese passwd ein
while IFS=: read account password uid gid rest; do
   # Werte nur Benutzeraccounts aus; uid >=1000
   # Ignoriere nobody
   if [ $uid -ge 1000 ] && [ "$account" != nobody ]; then
      # chage liefert das account expire Datum; mit date wird es in
      # Sekunden seit 1970 umgewandelt
      expire_date=$(chage -l $account | grep -i "Account expires" | cut -d: -f2 | tr -d '\t')
      if [[ "${expire_date,,}" =~ "never" ]]; then
         run_only_once
         echo "Warnung: Account ${account} hat kein expire Datum gesetzt."
         retval=1
      else
         expires=$(date -d "$expire_date" +%s)
         if [ $expires -le $now ]; then
            last_report=$(echo "$(($now - $expires))%$interval" | bc)
            if [ $last_report -le 86400 ]; then  # $last_report is younger than a day
               run_only_once
               printf "%-16s abgelaufen am '$expire_date'\n" ${account}:
               retval=1
            fi
         else
            if [ -n "$DEBUG" ]; then
               printf "%-16s gültig bis '$expire_date'\n" ${account}:
            fi
         fi
      fi
   fi
done < /etc/passwd

exit $retval
