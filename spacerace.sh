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

pos=40
width=80

while true; do
   read -t1 -s -n1 x
   case "$x" in 
      g) pos=$(($pos - 1)) ;;
      h) pos=$(($pos + 1)) ;;
   esac
   for ((i=0; i < $width; i++))
   do
      if [ $i -eq $pos ]; then
         echo -n 'V'
      elif [ $(($RANDOM % 9)) -eq 0 ]; then
         echo -n '*'
      else
         echo -n ' '
      fi
   done
   echo
done

