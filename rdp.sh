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

HOSTS="host1.example.com host2.example.com"
DEFAULT="host1.example.com"
TITLE="rdesktop starten"
MSG="Session auswählen"
RESOLUTION=${1:-"1280x1024"}

while true; do
  STATUS=$(kdialog --title "$TITLE" --combobox "$MSG" $HOSTS --default $DEFAULT)

   if [[ $? = 0 ]]; then
      case $STATUS in
         "host1.example.com")
            rdesktop -a 16 -g $RESOLUTION -u "user1@host" -p 'geheim' "$STATUS";
            ;;
         "host2.example.com")
            rdesktop -a 16 -g $RESOLUTION -u "user2@host" -p 'geheim' "$STATUS";
            ;;
      esac
   else 
      exit
   fi
done
