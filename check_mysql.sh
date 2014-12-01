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

MMM_PATH="/usr/sbin"
CHECK="$MMM_PATH/mmm_control checks"
SHOW="$MMM_PATH/mmm_control show"
RCPT="root@localhost"
STATUSFILE="/var/run/mysql-mmm.error"

OUTPUT=$($CHECK)

## check if an admin has set a host offline
## send mail only if host is not in ADMIN state
if ! grep -q 'ADMIN_OFFLINE' <<< "$($SHOW)"; then
   if grep -vq OK <<< "$OUTPUT"; then
      if ! [ -e $STATUSFILE ]; then
         touch $STATUSFILE
         for i in $RCPT; do
            /usr/bin/mail -s "MMM reports an error!" "$i" <<< "$OUTPUT"
         done
      fi
      # else skip sending mail, because we send already one 
   else
      if [ -e "$STATUSFILE" ]; then 
         rm -f $STATUSFILE
         for i in $RCPT; do
            /usr/bin/mail -s "MMM OK again !" "$i" <<< "$OUTPUT"
         done
      fi
   fi
fi

