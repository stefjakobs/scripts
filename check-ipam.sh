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

# Vorraussetzungen:
# - transport table
# - Mailrelay Abhängigkeiten mit dem folgenden Format:
#   * CSV Datei, mit Hostnamen in Anführungszeichen ("") im ersten Feld 
#   * Alles nach dem 2. Anführungszeichen wird ignoriert.
# ODER
#   * Jeder Host in einer Zeile, eingeleitet von: '   - '
#   * Alles andere wird ignoriert


MAILRELAY='mx1.example.com'

usage() {
   echo "$0 <transport table> <mr dependencies>"
   exit 1
}

# Überprüfe, ob wir zwei Parameter haben
if [ -z $2 ]; then 
  usage;
else
  if ! ( test -r $1 && test -r $2 ); then
    echo "Kann Dateien nicht lesen."
    exit 1
  else
    TRANSPORT="$1"
    DEPENDS="$2"
  fi
fi

# Sortiere die Dateien
TRANSPORT_SORTED=$(mktemp) #&& echo "Transport table, sortiert: $TRANSPORT_SORTED"
DEPENDS_SORTED=$(mktemp)   #&& echo "Dependencies, sortiert: $DEPENDS_SORTED"
egrep -v "^#|^\s*$" $TRANSPORT | sort -k 1b,1 | uniq > $TRANSPORT_SORTED
# Finde heraus welches Dateiformat wir haben
FIRST=$(head -1 $DEPENDS | cut -d',' -f1)
if [ "$FIRST" = '"Name"' ]; then
   # CSV Format
   tail -n +2 $DEPENDS | egrep -v "^#|^\s*$" $DEPENDS | sed -n 's/^"\([^"]*\)".*/\1/p' | sort -k 1b,1 | uniq > $DEPENDS_SORTED
else 
   # unübliches Format
   egrep -v "^#|^\s*$" $DEPENDS | sed -n 's/   - //p' | sort -k 1b,1 | uniq > $DEPENDS_SORTED
fi

# Erstelle eine Liste mit hosts, die nicht über die transport table
# verschickt werden
NO_TRANSPORT=$(mktemp)     #&& echo "Kein Transport: $NO_TRANSPORT"
join -v2 $TRANSPORT_SORTED $DEPENDS_SORTED | sort -k 1b,1 | uniq > $NO_TRANSPORT

# entferne den Hostnamen von der eben erstellten Liste und sortiere diese
DOMAINS=$(mktemp)	   #&& echo "Domainen: $DOMAINS"
sed 's/^[^.]*\./\./' $NO_TRANSPORT | sort -k 1b,1 | uniq > $DOMAINS

# Entferne alle Einträge für die es einen passenden CatchAll für
# Subdomains in der Transport table gibt:
LIST="$(join -v2 $TRANSPORT_SORTED $DOMAINS | tr '\012' ' ')"

# Finde alle Hosts die zu den übrig gebliebenen Einträgen gehören:
NO_TRANS_CATCH=$(mktemp)   #&& echo "Kein Transport, kein CatchAll: $NO_TRANS_CATCH"
for item in $LIST; do
  egrep "^[^.]*\.${item#.}" $NO_TRANSPORT >> $NO_TRANS_CATCH
done

# Überprüfe, ob die restlichen Einträge nicht über das DNS gemanaged werden:
LIST=""
while read line; do
   ERG=$(host -t mx $line | grep -v "$MAILRELAY")
   if [ -z "$ERG" ]; then
      LIST=$(echo -e "$LIST\n$line")
   fi
done < $NO_TRANS_CATCH

echo "$LIST"| sort | uniq

rm $TRANSPORT_SORTED
rm $DEPENDS_SORTED
rm $NO_TRANSPORT
rm $DOMAINS
rm $NO_TRANS_CATCH
