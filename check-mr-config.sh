#!/bin/bash

# Copyright (c) 2012 Stefan Jakobs <projects AT localside.net>
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
# Das Skript überprüft jeden Eintrag in der Transport table auf 
# Gültigkeit. Dazu extrahiert es zunächst die Einträge auf der linken
# Seite und prüft, ob für diese das $MAILRELAY als DNS MX-record
# eingetragen ist. Kommentare und E-Mailadressen werden ignoriert.
# Anschließend extrahiert es die Nexthop Einträge auf der rechten
# Seite, wobei es $IGNORE Einträge ignoriert. Das Skript über-
# prüft anschließend, ob der Port 25 auf diesen Hosts erreichbar ist.
#
# Das Skript überprüft dann, jeden Eintrag in der domain map auf 
# Gültigkeit. Dazu versucht es gleiche Einträge in der transport
# table zu finden. Wenn es diese nicht gibt, dann überprüft es noch,
# ob es einen zweiten DNS MX-record gibt.
#
# Format transport table: domain	transport:Nexthop
# Nexthop kann in eckigen Klammern stehen
# transport: kann ignoriert werden, siehe $IGNORE
#
# Format domain map: [!]domainname

MAILRELAY="mx.example.com"
IGNORE="nonmx-smtp:|error:|retry:"
SMTPPORT=25

usage() {
   echo "$0 <transport table> <domain map> [<restriction table> ...]"
   exit 1
}


##### Functions #####
SPACE="   "
# Überprüfe den Domänenteil der transport table
# Wildcards für Subdomänen werden in die Domäne umgewandelt
# Anschließend wird überprüft, ob $MAILRELAY als MX-record eingetragen ist.
check_domain() {
   local dom=$1
   if grep -q "^\." <<< "$dom"; then
      dom=${dom/./}
   fi
   if ! $DIG -t mx $dom | grep "$MAILRELAY" &> /dev/null ; then
      echo "${SPACE}${dom}"
   fi
}

# Überprüfe, ob es zwei oder mehr MX-records gibt und einer davon
# $MAILRELAY ist.
check_different_mx() {
   local dom=$1
   if grep -q "^\." <<< "$dom"; then
      dom=${dom/./}
   fi
   local MX=$($DIG +short -t mx $dom)
   local MXmr=$(grep -c $MAILRELAY <<<"$MX")
   local MXnonmr=$(grep -cv $MAILRELAY <<<"$MX")
   if ! ( [ "$MXmr" -eq 1 ] && [ "$MXnonmr" -gt 0 ] ); then
      echo "${SPACE}${dom} (Ziel: $(grep -v $MAILRELAY <<<"$MX"))"
   fi
}

# Überprüfe, ob der als Nexthop angegebene Host auf Port 25 hört
# Ist nexthop eine IPv4-Adresse, dann versuche den Reverse record
# zu ermitteln.
check_nexthop() {
   local hop=$1
   if ! $NC -z $hop $SMTPPORT &> /dev/null; then
      if egrep "([0-9]{1,3}\.){3}[0-9]{1,3}" > /dev/null <<< $hop; then
         hopIP=$($DIG +short -x $hop)
         echo "${SPACE}${hop} (is $hopIP)"
      else
         echo "${SPACE}${hop}"
      fi
   fi
}

# Schreibe die Beschreibung DESC gefolgt von der Ausgabe OUT nach STDOUT
print_result() {
   local OUT=$1
   local DESC=$2
   if [ -n "$OUT" ]; then
      echo -e "$DESC"
      echo "$OUT"
      echo
   fi
}

# Überprüfe, ob die übergebene Domäne in der domain map aufgelistet ist.
# Wenn nicht wiederhole die gleiche Überprüfung für die übergeordnete
# Domäne, solange bis die TLD erreicht ist.
check_relaying_allowed() {
   local dom=$1
   if grep -q "\." <<< "$dom"; then
      if ! grep -q "$dom" <<< "$D_DOMAINS"; then
         check_relaying_allowed "$(cut -d. -f2- <<<"$dom")"
      fi
   else
      false
   fi
}

# Überprüfe, ob 
check_restriction_domain() {
   local dom=$1
   if grep -q "^\." <<< "$dom"; then
      dom=${dom/./}
   fi
   if ! grep -q "$dom" <<< "$T_DOMAIN_PART"; then
      echo "${SPACE}${dom}"
   fi
}
##### End of functions #####

# Überprüfe, ob wir einen Parameter haben
if [ -z $1 ] || [ -z $2 ]; then 
   usage
else
   if ! ( test -r $1 ); then
      echo "Fehler: Kann angegebene Transport table nicht lesen."
      exit 1
   else
      TRANSPORT_TABLE="$1"
   fi
   if ! ( test -r $2 ); then
      echo "Fehler: Kann angegebene Domain map nicht lesen."
      exit 1
   else
      DOMAIN_MAP="$2"
   fi
   shift
   shift
fi

# Überprüfe die restlichen Parameter (restriction tables)
for i in $(seq 1 $#); do
   if ! (test -r $1 ); then
      echo "Fehler: Kann die Restricion table $1 nicht lesen."
      exit 1
   else
      RESTRICTION_TABLE[$i]="$1"
   fi
done

# Überprüfe, ob es nc und dig gibt:
if which nc &> /dev/null; then
   NC=$(which nc)
elif which netcat &> /dev/null; then
   NC=$(which netcat)
else
   echo "Fehler: netcat (nc) ist nicht installiert!"
   exit 1
fi
if which dig &> /dev/null; then
   DIG=$(which dig)
else
   echo "Fehler: dig ist nicht installiert!"
   exit 1
fi

# Überprüfe, ob es mktemp gibt:
if ! which mktemp &> /dev/null; then
   echo "Fehler: mktemp nicht gefunden!"
   exit 1
fi

# Extrahiere die linke Seite aus der Transport table
# ignoriere Zeilen, die mit # starten, leer sind oder ein @ (E-Mail) enthalten
T_DOMAIN_PART_ALL=$(egrep -v "^#|^\s*$" $TRANSPORT_TABLE | expand | cut -d" " -f1 | \
      sort -k 1b,1)
T_DOMAIN_PART=$(uniq <<< "$T_DOMAIN_PART_ALL")

# Überprüfe, ob es doppelte Einträge gibt
OUTPUT=$(uniq -cdi <<< "$T_DOMAIN_PART_ALL")
print_result "$OUTPUT" "Doppelte Einträge in $TRANSPORT_TABLE:"

# Überprüfe, ob ein MX-record für den domain part gesetzt ist
OUTPUT=$(\
for dom in $T_DOMAIN_PART; do
   check_domain $dom &
done )
wait
print_result "$OUTPUT" "Relay eingerichtet, aber kein passender DNS MX-record vorhanden:"

# Extrahiere die rechte Seite aus der Transport table
# ignoriere Zeilen, die leer sind oder $IGNORE als Inhalt haben
T_NEXTHOPS=$(egrep -v "^#|^\s*$|${IGNORE}" $TRANSPORT_TABLE | cut -d: -f2 | \
	   grep -v "^$" | sort -k 1b,1 | uniq)

# Überprüfe, ob der nexthop auf Port $SMTPPORT antwortet
OUTPUT=$(\
for hop in $T_NEXTHOPS; do
   # entferne [ und ]
   hop=${hop#[}
   hop=${hop%]}
   check_nexthop $hop &
done )
wait
print_result "$OUTPUT" "Die folgenden Nexthops sind nicht auf Port $SMTPPORT erreichbar:"

# Extrahiere die Domänen aus der domain map
# ignoriere Zeilen, die leer sind oder mit einem ! beginnen
D_DOMAINS=$(egrep -v "^!|^#|^\s*$" $DOMAIN_MAP | cut -f1 | sort)

# Überprüfe, ob es doppelte Einträge gibt
OUTPUT=$(uniq -cdi <<< "$D_DOMAINS")
print_result "$OUTPUT" "Doppelte Einträge in $DOMAIN_MAP:"

# Überprüfe, ob diese Domänen $MAILRELAY als MX-record gesetzt haben
OUTPUT=$(\
for dom in $D_DOMAINS; do
   check_domain $dom &
done )
wait
print_result "$OUTPUT" "Die folgenden Domänen haben $MAILRELAY nicht als MX-record gesetzt:"

# Erstelle zwei temporäre Dateien für den Join-Vergleich
TMP_DOMAIN_MAP=$(mktemp)
TMP_TRANSPORT_TABLE=$(mktemp)

# Extrahiere, und sortiere die Domainnamen aus der domain map und der
# transport table. Finde alle Einträge aus der domain map, die keinen
# gleich lautenden Eintrag in der transport table haben
egrep -v "^\s*$|^#|^!" $DOMAIN_MAP | sort -k 1b,1 > $TMP_DOMAIN_MAP
egrep -v "^\s*$|^#" $TRANSPORT_TABLE | sort -k 1b,1 > $TMP_TRANSPORT_TABLE
JOIN_DT=$(join -i -v 1 -1 1 -2 1 $TMP_DOMAIN_MAP $TMP_TRANSPORT_TABLE)
# Überprüfe, ob es zwei oder mehr MX-records gibt:
OUTPUT=$(\
for dom in $JOIN_DT; do
   check_different_mx $dom &
done )
wait
print_result "$OUTPUT" "Die folgenden Domänen dürfen relayen, haben aber kein Ziel gesetzt:"

# Stelle sicher, dass Domänen, für die nicht relayed werden darf, auch keinen
# Eintrag in der transport table haben
grep "^!" $DOMAIN_MAP | cut -d"!" -f2 | sort -k 1b,1 > $TMP_DOMAIN_MAP
JOIN_DT=$(join -i -1 1 -2 1 $TMP_DOMAIN_MAP $TMP_TRANSPORT_TABLE)
print_result "$JOIN_DT" "Die folgenden Domänen haben eine transport route, sollen aber nicht relayed werden:\n   (!DOMÄNE in $DOMAIN_MAP, aber nexthop in $TRANSPORT_TABLE)"

# Entferne die temporären Dateien
rm $TMP_DOMAIN_MAP
rm $TMP_TRANSPORT_TABLE


# Überprüfe, ob jede Domäne in der transport table auch in der domain map steht
OUTPUT=$(\
for dom in $T_DOMAIN_PART; do
   if ! check_relaying_allowed "$dom"; then
      echo "${SPACE}${dom}"
   fi
done )
print_result "$OUTPUT" "Relaying nicht erlaubt, aber Route existiert für:"

# Überprüfe, ob es einen Eintrag in der restriction table gibt, der nicht
# in der transport table steht.
for i in $(seq 1 ${#RESTRICTION_TABLE[*]}); do
   # Extrahiere die linke Seite aus der restriction table
   # ignoriere Zeilen, die mit # starten, leer sind oder ein @ (E-Mail) enthalten
   R_DOMAIN_PART_ALL=$(egrep -v "^#|^\s*$|\b@\b" ${RESTRICTION_TABLE[$i]} | \
      expand | cut -d" " -f1 | sort -k 1b,1)
   R_DOMAIN_PART=$(uniq <<< "$R_DOMAIN_PART_ALL")

   # Überprüfe, ob es doppelte Einträge gibt
   OUTPUT=$(uniq -cdi <<< "$R_DOMAIN_PART_ALL")
   print_result "$OUTPUT" "Doppelte Einträge in ${RESTRICTION_TABLE[$i]}:"

   # Überprüfe, ob der domain part auch in der transport table aufgeführt ist
   OUTPUT=$(\
   for dom in $R_DOMAIN_PART; do
      check_restriction_domain "$dom"
   done | sort -fu )
   print_result "$OUTPUT" "In ${RESTRICTION_TABLE[$i]} aufgeführt, aber nicht in $TRANSPORT_TABLE:"

done

postfix check
