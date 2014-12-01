#!/bin/bash

if [ -z "$1" ] || ! /usr/bin/ipcalc -c $1; then
   echo "usage: $0 <ip addr>"
   exit 1
fi
IP="$1"

for opt in -h -m -n -b -p ; do
   OUT="$(/usr/bin/ipcalc $opt $IP)"

   NAME="$(echo $OUT | cut -d= -f1)"
   VALUE="$(echo $OUT | cut -d= -f2)"

   printf "%-10s = %s\n" $NAME $VALUE
done

