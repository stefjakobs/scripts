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

#echo -n "Herunterfahren (h) oder neustarten (n): "

#while read -n 1 line; do
#  case $line in 
#    "h"|"H") echo -e "\n\nDer Computer wird heruntergefahren!";
#	     sudo /sbin/halt;
#	     exit; 
#	     ;;
#    "n"|"N") echo -e "\n\nDer Computer wird neugestartet!";
#	     sudo /sbin/reboot;
#	     exit;
#	     ;;
#    *) echo -en "\nFalsche Eingabe. Bitte \"n\" oder \"h\" eingeben: ";
#	     ;;
#  esac
#done

#kdialog --yesnocancel "Herunterfahren (Ja) oder neustarten (Nein)?"
#
#case $? in
#     "0") sudo /sbin/halt;
#	  exit;
#	  ;;
#     "1") sudo /sbin/reboot;
#	  exit;
#	  ;;
#     "2") exit;
#	  ;;
#esac

STATUS=`kdialog --title "Beenden?" --combobox "Diese Sitzung beenden?" Herunterfahren Neustarten Standby Suspend Hibernate --default Herunterfahren`

if [[ $? = 0 ]]; then
  case $STATUS in
     "Herunterfahren")
      	sudo /sbin/poweroff;
			exit;
			;;
     "Neustarten")
     	   sudo /sbin/reboot;
			exit;
			;;
     "Standby")
     		/usr/bin/powersave -m;
			exit;
			;;
     "Suspend")
     		/usr/bin/powersave -u;
			exit;
			;;
     "Hibernate")
     	   /usr/bin/powersave -U;
			exit;
			;;
  esac
fi

