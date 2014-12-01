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

#################################################################
# Beschreibung:
# Dieses Script fuert "postmap -q" oder "postmap -d" auf jedem 
# in $HOSTS angegebenen Rechner ueber ssh auf. Dabei ist die 
# Option "-d" der default. Als Uebergabeparameter muss mindestens
# eine e-Mail Adresse angegeben werden.
USAGE="usage: $0 [-q|-d] user1@domain1.tld [user2@domain2.tld ...]"
#################################################################

VERIFY="/var/lib/postfix/verify"
POSTMAP=$(which postmap)
POSTCONF=$(which postconf)
HOSTS="host1 host2"
START=2
END=$#

# check if the postmap command exists
if [ -z $POSTMAP ]; then
   echo "Can not find postmap!"
   echo 
   exit 2
fi
# check postfix Version and set verify
if [ -n $POSTCONF ]; then
   VERIFY=$($POSTCONF address_verify_map | cut -d":" -f2 )
fi

# check if the caller choose the right options
if (( $END >= 2 )); then
   if [ $1 == "-d" ] || [ $1 == "-q" ]; then 
      QD=$1
   else
      echo "Wrong option!"
      echo "usage: $USAGE"
      echo
      exit 2
   fi
elif (( $END == 1 )); then
   QD="-d"
   START=1
else 
   echo "You must specify an address!"
   echo "usage: $USAGE"
   echo
   exit 2
fi

if (( $END >= 2 )); then shift; fi
for NUM in `seq $START $END`; do
   for NAME in $HOSTS; do
      printf "%-11s" $NAME: ; 
      # Use this one later with the new sudoers file on the mailrelays
      #ssh $NAME sudo postmap $QD $1 btree:$VERIFY
      RETURN="$(ssh root@$NAME postmap $QD $1 btree:$VERIFY)"
      RETVAL=$?
      if [ -n "$RETURN" ]; then 
         DATE=$(date -d @"$(echo $RETURN | cut -d: -f 3 )" +"%d.%m.%Y %H:%M:%S")
         echo "$RETURN"      
         printf "\t   last update: %s\n" "$DATE"
      else
         if [ $QD == "-d" ] && [ $RETVAL -eq 0 ]; then echo -e "\t deleted!"; else echo ; fi
      fi
      #echo "ssh $NAME sudo postmap $QD $1 btree:$VERIFY"
   done 
   shift
   echo
done
