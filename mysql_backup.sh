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

# TARGET: Backup-Ziel
# IGNORE: Liste zu ignorierender Datenbanken (durch | getrennt)
# CONF: MySQL Config-Datei, welche die Zugangsdaten enthaelt
TARGET=/var/backups/mysql
IGNORE="phpmyadmin|mysql|information_schema|performance_schema|test"
CONF=/etc/mysql/debian.cnf
OPTIONS="--single-transaction --skip-extended-insert --skip-comments"
STATUS=0
if [ ! -r $CONF ]; then /usr/bin/logger "$0 - auf $CONF konnte nicht zugegriffen werden"; exit 1; fi
if [ ! -d $TARGET ] || [ ! -w $TARGET ]; then /usr/bin/logger "$0 - Backup-Verzeichnis nicht beschreibbar"; exit 1; fi

DBS="$(/usr/bin/mysql --defaults-file=$CONF -Bse 'show databases' | /bin/grep -Ev $IGNORE)"
STATUS=$?
NOW=$(date +"%Y-%m-%d")

for DB in $DBS; do
    /usr/bin/mysqldump --defaults-file=$CONF $OPTIONS $DB > $TARGET/$DB.sql && \
    gzip -f $TARGET/$DB.sql
    new_status=$?
    if [ $STATUS = 0 ]; then
       STATUS=$new_status
    fi
done

if [ $STATUS = 0 ]; then
   touch $TARGET/Backup.OK
   /usr/bin/logger "$0 - Backup von $NOW erfolgreich durchgefuehrt"
else 
   /usr/bin/logger "$0 - Backup von $NOW fehlgeschlagen"
fi
exit $STATUS
