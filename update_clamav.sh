#!/bin/bash

#################################################################
# Autor: Stefan Jakobs
# Version: 0.4.1
# Release: 0 
# last change: 13.05.09
#######################
# Beschreibung:
#
# Dieses Script fuehrt ein Update fuer clamAV durch
# Beim Starten muss der Pfad zum tar-file mit angegeben werden.
# Zuerst wird probiert die alte ClamAV-Installation mittels
# "make uninstall" der alten Quellen zu loeschen. Wenn dies
# nicht funktioniert, dann werden die Bibliotheken vom Script
# selbst geloescht.
# Anschliessend wird die neue ClamAV Version mittels configure,
# make, make install installiert.
# Ueber die Variable ZLIB_CHK ist es moeglich die Ueberpruefung
# der ZLib Version zu deaktivieren. Ausserdem kann der Pfad zu 
# einer eigenen Zlib Bibliothek ueber die Variable ZLIB_DIR
# angegeben werden.
# Alle Ausgabe Meldungen werden in die folgende Datei geschrieben:
# /MAILRELAY-SETUP/AV-SCANNERS/clamav-install.debug
# Diese ist ueber die Variable LOG_FILE konfigurierbar.
#
# Changelog: siehe Dateiende
#
#################################################################

######################
## Beginn Variablen ##

ZLIB_CHK=1			# 0: Automatische Zlib Pruefung; 
				# 1: keine Pruefung
ZLIB_DIR=0			# 0 oder Angabe des Zlib Verzeichnisses

while getopts " a:H h n z Z:" opt ; do
  case $opt in
    a ) CLAM_TAR=$OPTARG ;;
    h | H )  tee << EOT

Dieses Script fuehrt ein Update fuer ClamAV durch. Dazu muss dem Script
der Pfad zum tar.gz-file der neuen ClamAV Version uebergeben werden
(z.B.: update_clamav.sh /tmp/clamav-0.86.2.tar.gz).

Danach entpackt das Script die Dateien, sichert die conf-files, loescht
die alte Installation, fuehrt ein configure, make, make install durch
und startet den daemon neu. Zum Schluss wird ps ausgefuehrt, um zu
ueberpruefen, ob clamd richtig gestartet wurde.
Das Skript prueft die ZLib Version nicht. Es ist darauf zu achten, dass
eine aktulle Version installiert ist.

Optionen:
   -a <archiv>	...der Pfad zum ClamAV tar-file
   -h		...gibt diese Hilfe aus
   -n		...laesst den Benutzer vor der Installation die
		   README und CHANGELOG Dateien lesen
   -z		...der automatische Zlib Check wird eingeschaltet
   -Z <Pfad>	...Pfad zur Zlib Bibliothek (falls abweichend)

EOT
	exit 0
	;;
     n) READ_INFO="true" ;;		# uebergebener Parameter Buchstabe
     z) ZLIB_CHK=1 ;;			# Zlib check einschalten
     Z) ZLIB_DIR=$OPTAG ;;		# Zlib Pfad setzen
     ?) exit 5 ;;			# bei falschem Flag beenden
  esac
done

if [ -z $CLAM_TAR ] ; then
  for i ; do CLAM_TAR=$i ; done
  if [ -z $CLAM_TAR ] || [[ $CLAM_TAR == -? ]] ; then
    echo -e "FEHLER: Kein Archiv uebergeben!\n"
    exit 5
  fi
fi

if ! $(echo $CLAM_TAR | grep \\.tar\\.gz > /dev/null) ; then
  echo "Uebergebene Datei scheint kein tar.gz file zu sein."
  echo "Bitte ein Archiv uebergeben oder ClamAV haendisch installieren!"
  echo " - ABBRUCH -"
  echo 
  exit 5
fi

TAR_LENGTH=$(expr length $CLAM_TAR)	# Zeichenlaenge des tar-files
OLD_DIR=""			# Die alten Quellen
RCCLAMD=/sbin/rcclamd		# Das init-Script fuer clamd

# Das Verzechnis in das ClamAV installiert wird
INST_DIR=/usr/local/clamav

# Verzeichnis in das entpackt werden soll
SCANNER_DIR=/MAILRELAY-SETUP/AV-SCANNERS/

# Verzeichnis fuer das configure-Script
CLAM_DIR=$(expr substr $CLAM_TAR 1 $(expr $TAR_LENGTH - 7))

# Version der aktuellen ClamAV Installation
if ( test -x $INST_DIR/bin/clamscan ); then
  CLAM_VERSION=`$INST_DIR/bin/clamscan -V | cut -b 8-13 | cut -d "/" -f 1`
else 
  CLAM_VERSION="???"
fi

# Verzeichnis der neuen ClamAV Installation
if (( $TAR_LENGTH < 15 )); then LENGTH=15; else LENGTH=$TAR_LENGTH; fi
NEW_CLAM_VERSION="clamav-$(echo $CLAM_TAR\
	 | cut -b $(expr $LENGTH - 15)-$(expr $LENGTH - 7)\
	 | cut -d "-" -f 2)"

# Ueberpruefe ob /sbin im PATH liegt, wenn nicht fuege es hinzu
if ( expr $PATH : :/sbin > /dev/null 2>&1 ) || \
   ( expr $PATH : /sbin: > /dev/null 2>&1 ); then
  PATH_BAK=0
else
  PATH_BAK=$PATH
  PATH=/sbin:$PATH
fi

# Datei in der die debug-Ausgabe gespeichert wird
LOG_FILE=${SCANNER_DIR}clamav-install.debug

# README und ChangeLog Pfad
README=${NEW_CLAM_VERSION}/README
CHANGELOG=${NEW_CLAM_VERSION}/ChangeLog

## Ende Variablen ##
####################

#######################
## Beginn Funktionen ##

# Schreibe alten PATH zurueck
function wb_old_path ()
{
  if ( expr $PATH_BAK = 0 > /dev/null 2>&1 ); then
    PATH=$PATH_BAK
  fi
}

# Lese YES/NO ein
function yes_no ()
{
  STATUS=2
  read YESNO
  while (( $STATUS==2 )); do
     if (expr $YESNO : yes > /dev/null 2>&1 ) || \
        (expr $YESNO : YES > /dev/null 2>&1 ); then
        STATUS=0
     elif (expr $YESNO : no > /dev/null 2>&1 ) || \
          (expr $YESNO : NO > /dev/null 2>&1 ); then
        STATUS=5
     else 
	echo -n "Ungueltige Eingabe! Wiederholen Sie (yes|no):  "
        read YESNO
     fi
  done
  return $STATUS
}

# Gebe Fehlermeldung aus
function abbruch ()
{
  if ( test "$1" ); then 
    echo -e "\n$1"
  else
    echo -e "\nEs ist ein Fehler aufgetreten!"
  fi
  echo "Abbruch des Skripts!"
  wb_old_path
  exit 5
}
  

# Sichere die Konfigurationsdateien
function save_conf ()
{
  echo -en "Die conf-files sichern ...\t\t\t\t\t"
  if !( cp $INST_DIR/etc/freshclam.conf $INST_DIR/etc/freshclam.conf.old \
	>> $LOG_FILE 2>&1) ; then
    echo -e "\nFEHLER! Konnte freshclam.conf nicht sichern.\n"
    echo -n "Moechten Sie trotzdem fortfahren? (yes|no)   "
    yes_no || abbruch 'Abbruch durch Benutzer.'
  fi
  if !( cp $INST_DIR/etc/clamd.conf $INST_DIR/etc/clamd.conf.old \
	>> $LOG_FILE 2>&1 ); then
    echo -e "\nFEHLER! Konnte clamd.conf nicht sichern.\n"
    echo -n "Moechten Sie trotzdem fortfahren? (yes|no)   "
    yes_no || abbruch 'Abbruch durch Benutzer.'
  fi
  echo "gesichert"
}

# Alte Bibliotheken loeschen
function delete_lib ()
{
  echo -en "Librarys loeschen ...\t\t\t\t\t\t"
  if !( rm -fr $INST_DIR/old_lib/* >> $LOG_FILE 2>&1 ); then
    echo -en "FEHLER!\nKonnte librarys in old_lib nicht loeschen!\n"
    echo -en "\nMoechten Sie die Installation fortsetzen? (yes|no)  "
    yes_no || abbruch 'Abruch durch Benutzer!' 
  fi
  if !( mv $INST_DIR/lib/* $INST_DIR/old_lib/ >> $LOG_FILE 2>&1 ); then
    echo -e "FEHLER!\nKonnte aktuelle librarys nicht sichern"
    echo
    echo -n "Moechten Sie die Installation fortsetzen? (yes|no)  "
    yes_no || abbruch 'Abruch durch Benutzer!'
  else echo "geloescht"
  fi
}

# Entpacke die ClamAV Quellen
function extract_clam ()
{
  echo -en "Die sourcen nach $SCANNER_DIR entpacken ...\t"
  if (test -e $CLAM_TAR && test -d $SCANNER_DIR); then
    if !(tar xzf $CLAM_TAR -C $SCANNER_DIR >> $LOG_FILE 2>&1 ); then
	abbruch 'Das angegebene Archiv konnte nicht entpackt werden!'
    fi
    echo "entpackt"
  else abbruch '$CLAM_TAR oder $SCANNER_DIR existiert nicht!'
  fi
}

# Installiere neues ClamAV
function install_clam ()
{
  cd $SCANNER_DIR
  cd $CLAM_DIR
  echo -en "Mache: ./configure ...\t\t\t\t\t\t"
  if expr $ZLIB_CHK = 1 > /dev/null 2>&1; then
     ./configure --prefix=$INST_DIR --disable-zlib-vcheck >> $LOG_FILE 2>&1
  elif expr $ZLIB_DIR != 0 > /dev/null 2>&1; then
     ./configure --prefix=$INST_DIR --with-zlib=$ZLIB_DIR >> $LOG_FILE 2>&1
  else ./configure --prefix=$INST_DIR >> $LOG_FILE 2>&1
  fi
  if (( $?!=0 )); then abbruch 'Fehler in configure!' 
  else 
     echo -en "fertig\nMache: make ...\t\t\t\t\t\t\t"
     make >> $LOG_FILE 2>&1
     if (( $?!=0 )); then abbruch 'Fehler in make!'
     else 
	echo -en "fertig\nMache: check ...  \t\t\t\t\t\t"
	make check >> $LOG_FILE 2>&1
	if (( $?!=0 )); then abbruch 'Fehler in make check!'
	else 
	   echo -en "fertig\nMache: install ...\t\t\t\t\t\t"
	   make install >> $LOG_FILE 2>&1
           if (( $?!=0 )); then abbruch 'Fehler in make install!'
           else 
	      echo -en "fertig\nMache: clean ...\t\t\t\t\t\t"
	      make clean >> $LOG_FILE 2>&1 || abbruch 'Fehler in make clean!'
	      echo -en "fertig\n"
	   fi
        fi
     fi
  fi
}

# Stoppe Clamd
function stop_clam ()
{
  echo "ClamAV Daemon anhalten ..."
  $RCCLAMD stop || { 
	echo -e "\nFehler! clamd konnte nicht beendet werden.\n"
	echo -n "Moechten Sie mit der Installation fortfahren? (yes|no):  "
	yes_no || abbruch 'Abbruch durch Benutzer!'
  }
}

# Starte Clamd 
function start_clam ()
{
  $RCCLAMD start || {
	echo "Fehler! clamd konnte nicht gestartet werden."
	echo "Abbruch"
	abbruch	
  }
  echo
  echo ------------------------
  echo !ClamAV wurde upgedatet!
  echo ------------------------
  echo
  sleep 3
  ps -jf -C clamd
}

# Verschiebe das alte Verzeichnis nach old/
function move_dir ()
{
  echo -en "Verschiebe das alte Quellverzeichnis nach old ...\t\t"
  # Ueberpruefe, ob es ein altes Verzeichnis gibt
  if ( test -d ${SCANNER_DIR}clamav-$CLAM_VERSION ); then
    if ( test -d ${SCANNER_DIR}old/ ); then
       mv ${SCANNER_DIR}clamav-$CLAM_VERSION ${SCANNER_DIR}old/ \
	>> $LOG_FILE 2>&1
       mv ${SCANNER_DIR}clamav-$CLAM_VERSION.tar.gz* ${SCANNER_DIR}old/ \
	>> $LOG_FILE 2>&1
       echo "verschoben"
    else
       echo -en "\nErstelle old Verzeichnis und verschiebe ...\t\t\t"
       mkdir ${SCANNER_DIR}old/ >> $LOG_FILE 2>&1
       mv ${SCANNER_DIR}clamav-$CLAM_VERSION ${SCANNER_DIR}old/ \
        >> $LOG_FILE 2>&1
       mv ${SCANNER_DIR}clamav-$CLAM_VERSION.tar.gz* ${SCANNER_DIR}old/ \
        >> $LOG_FILE 2>&1
       echo "verschoben"
   fi
  else echo "skipped"
  fi
}	

## Ende Funktionen ##
#####################

echo -en "\n\n!! STARTE UPGRADE !!\n\n"

# Lasse den Benutzer die README- und ChangeLog Datei lesen
if [[ $READ_INFO == "true" ]]; then
   tar xzfO $CLAM_TAR $README | less
   tar xzfO $CLAM_TAR $CHANGELOG | less
   echo "Möchten Sie mit dem Upgrade fortfahren? (yes|no)"
   yes_no || abbruch 'Es wurden keine Änderungen am System vorgenommen!'
fi

# Loesche alte Logdatei
test -w $LOG_FILE && rm $LOG_FILE || echo "Konnte $LOG_FILE nicht loeschen" 

# Ueberpruefe, ob ein altes Source-Verzeichnis existiert
if ( test -d ${SCANNER_DIR}clamav-$CLAM_VERSION ) ; then
	OLD_DIR="${SCANNER_DIR}clamav-$CLAM_VERSION"
elif ( test -d ${SCANNER_DIR}old/clamav-$CLAM_VERSION ) ; then
	OLD_DIR="${SCANNER_DIR}old/clamav-$CLAM_VERSION"
else 
	echo "Kein altes Source-Verzeichnis gefunden!"
fi

# Wenn ein altes Source Verzeichnis existiert, dann
# fuehre "make uninstall" aus
if ( test "$OLD_DIR" ); then
  echo -e "Altes Quellverzeichnis ist: $OLD_DIR\n"
  extract_clam
  echo -en "Mache: make uninstall ...\t\t\t\t\t"
  cd $OLD_DIR
  if !( make uninstall >> $LOG_FILE 2>&1 ); then
	echo -e "\nFehler in: make uninstall!"
	## Uninstall wird durch dieses Skript ausgefuehrt.
	echo "Soll dies Skript selbst deinstallieren? (yes/no)"
	yes_no || abbruch 'Abbruch durch Benutzer!'
	save_conf
	stop_clam
	delete_lib
	echo -e "Uninstall durchgefuehrt!\n"
  else
	echo "fertig"
  fi
  ## STARTE INSTALLATION
  install_clam
  stop_clam
  move_dir
  start_clam

# Es existiert kein altes Quellverzeichnis
# Bibliotheken werden von diesem Skript selbst geloescht
else
  echo -en "\nMoechten Sie,dass dies Skript die Bibliotheken "
  echo -en "loescht? (yes|no)   "
  yes_no || abbruch 'Abbruch durch Benutzer!'
  extract_clam
  save_conf
  stop_clam
  delete_lib
  install_clam
  move_dir
  start_clam
  wb_old_path
fi

##### Changelog: #####
# * Son Sep 07 2007 - stefan.jakobs@rus.uni-stuttgart.de - v0.3.1
# - add: Ueberpruefung, ob der uebergebene Dateiname auf tar.gz endet
# - fix: Beschreibung von Parameter -n 
# - fix: Erkennen von Versionen der Form X.YY (vorher nur X.YY.Z)
# - add: Optionen -a, -z und -Z
# * Wed May 13 2009 - stefan.jakobs@rus.uni-stuttgart.de - v0.4.1
# - add: 'make check' in install_clam Funktion
