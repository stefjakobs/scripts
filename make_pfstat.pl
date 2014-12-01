#!/usr/bin/perl

# Copyright (c) 2014 Stefan Jakobs <projects AT localside.net>
####################################################################
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

########
# Beschreibung:
# Dieses Skript beschneidet die Ausgabe von pflogsumm.pl und
# schickt die Ausgabe dann an vorher definierte Email-Adressen
# oder gibt sie einfach auf der Shell aus.
#
# Um die Laenge der Ausgabe festzulegen wird dem Skript mit dem
# Parameter -l <Anzahl> eine natuerliche Zahl uebergeben (Standard:
# 10 Zeilen).
#
# Fuer weitere Optionen ruft man das Skript mit -h auf.
#
#################################################################

use strict;
use Getopt::Std;
use Date::Manip::DM5;
use File::Temp qw/ tempfile /;

require Mail::Send;

## Festlegen der Mail-Empfaenger
my $mailmon='mailmon@example.com';
my $TO="$mailmon";

## Definiere Absender
my $FROM='Statistiken <postfix_stats@example.com>';

## Deklaration von Variablen
my ($pf_fh, $path_to_pfstat)= tempfile ( DIR => "/var/tmp/" );
my $path_to_maillog="/var/log/postfix";
my $pflogsumm="/usr/sbin/pflogsumm";
my $new_file;
my $lines=10;
my $std_out=0;
my $send_mail=0;
my $msg = new Mail::Send;
my $helptext="Dieses Skript verkuerzt die Ausgabe von pflogsumm.pl "
		."auf eine Angegebene Zeilenanzahl.\n"
		."Man kann folgende Optionen angeben:\n"
		."\t-h 			... zeigt diesen Text an\n"
		."\t-m			... die Ausgabe wird als Email verschickt\n"
		."\t-s			... die Ausgabe wird in die Shell ausgeben\n"
		."\t-f <Pfad/Dateiname>	... der Pfad zu der Ausgabe von pflogsumm\n"
		."\t-l <Anzahl>		... die Anzahl der Zeilen auf die gekuerzt wird\n"
		."\t-o <Pfad/Dateiname>	... die Ausgabe wird in die angegebene Datei geschrieben.\n";

our ($opt_f, $opt_h, $opt_l, $opt_m, $opt_o, $opt_s);
getopt('fol');
getopts('hsm');
if (defined($opt_f)) { $path_to_pfstat=$opt_f; }	# legt den Pfad fest
if (defined($opt_l)) { $lines=$opt_l; }			# legt die Anzahl der Zeilen fest
if (defined($opt_o)) { $new_file=$opt_o; }		# legt die Ausgabedatei fest
if (defined($opt_m)) { $send_mail=1; }			# versendet Ausgabe als Mail
if (defined($opt_s)) { $std_out=1; }			# Ausgabe auf Standard Outp
if (defined($opt_h)) { print $helptext; }		# gibt evtl. die Hilfe aus
elsif (!defined($opt_o) && !defined($opt_m) && !defined($opt_s))
{							# Keine Hilfe, also funkt. 
   print "Dem Skript wurde keine Ausgabemethode angegeben.\n"
	."Bitte geben Sie min. eine der folgenden Optionen an:\n"
	."\t-o </Pfad/Datei>\t...legt die Ausgabedatei fest\n"
	."\t-s \t\t\t...gibt die Ausgabe auf der Shell aus\n"
	."\t-m \t\t\t...schickt die Ausgabe als Mail an die vordefinierten Adressen\n";
}
else
{
## Erstelle Log summary
if ((system "$pflogsumm --smtpd_stats -u 100 -d today $path_to_maillog > $path_to_pfstat 2> /dev/null") != 0) 
{
   print "Beim Aufruf von pflogsumm.pl ist ein Fehler aufgetreten!\n"
        ."Das Skript wird beendet.\n\n";
   print "Weitere Infos in $path_to_pfstat\n";
   exit 5;
}

## Oeffne die Ausgabe von pflogstat lesend
open (PFSTAT, $path_to_pfstat);
flock (PFSTAT, 1);
my @pf_stat_file = <PFSTAT>;

## Lege Array fuer die Ausgabe an
my @stats;
my $stats_length=0;

## aktuelles Datum
my $heute = UnixDate("today", "%d.%m.%y");
## aktuelle Zeit
my $zeit = UnixDate("today","%k:%M");

## Schreibe den Kopf
$stats[$stats_length++]="Postfix log summaries for $heute. From 0:00 to $zeit.\n";

## Schreibe die ersten Zeilen in Ausgabe-Array
for (my $i=1; $i<30; $i++)
{
  $stats[$stats_length++]=$pf_stat_file[$i];
}

my $write_stat = 0;		# Wenn Element geschrieben werden soll > 0
foreach my $element (@pf_stat_file)
{
  ## Host/Doamin Summary: Message Delivery
  ## -------------------------------------
  if ($element=~"Host/Domain Summary: Message Delivery")
  {
     $write_stat=$lines+3;
     $element=~s/(top [0-9]{1,})/top $lines/;
  }

  ## Host/Domain Summary: Messages Received
  ## --------------------------------------
  if ($element=~"Host/Domain Summary: Messages Received")
  {
     $write_stat=$lines+3;
     $element=~s/(top [0-9]{1,})/top $lines/;
  }

  ## top XX Recipients by message count
  ## ----------------------------------
  if ($element=~"top [0-9]{1,4} Recipients by message count")
  {
     $write_stat=$lines+2;
     $element=~s/(top [0-9]{1,})/top $lines/;
  }

  ## top XX  Senders by message count
  ## --------------------------------
  if ($element=~"top [0-9]{1,4} Senders by message count")
  {
     $write_stat=$lines+2;
     $element=~s/(top [0-9]{1,})/top $lines/;
  }

  ## smtp delivery failures
  ## ----------------------
  if ($element=~"smtp delivery failures")
  {
     $write_stat=$lines+2;
     chomp $element;
     $element=$element . " \(top $lines\)\n---------";
  }

  ##   no route to host (total: XXXX)
  if ($element=~"[ ]{0,10} no route to host \(total: [0-9]{1,8}\)*")
  {
     $write_stat=$lines+1;
  }

  ## Warnings
  ## --------
  if ($element=~"Warnings")
  {
     $write_stat=$lines+2;
     chomp $element;
     $element=$element . " \(top $lines\)\n---------";
  }

  ## Fatal Errors: none
  if ($element=~"Fatal Errors: none") { $write_stat = 1; }

  ## Fatal Errors
  if ($element=~"Fatal Errors") { $write_stat = 4; }

  ## Panics: none
  if ($element=~"Panics: none") { $write_stat = 1; }

  ## Panics
  if ($element=~"Panics") { $write_stat = 4; }

  ## Master daemon messages: none
  if ($element=~"Master daemon messages: none") { $write_stat = 1; }

  ## Master daemon messages
  if ($element=~"Master daemon messages") { $write_stat = 4; }


  ## Wurde eine Zeile gefunden?
  ## Ja, dann schreibe nächsten $write_stat Zeilen
  if ($write_stat > 0)
  {
    $stats[$stats_length++]=$element;
    $write_stat--;
    if ($write_stat==0) 
    { 
       $stats[$stats_length++]="\n";
    }
  }
}

if (defined($new_file))
{
  ## Lege neue Datei an
  open (OUTPUT, ">$new_file");
  flock (OUTPUT, 2);
}

my $MAIL;
if ($send_mail==1)
{
  ## Lege neue Mail an
  my $msg = new Mail::Send Subject=>"Postfix-Statistiken (logsrv3) vom $heute - $zeit Uhr";
     $msg->to("$TO");
     $msg->set('From', "$FROM");
  $MAIL = $msg->open;
}

foreach my $elem (@stats)
{
  if ($std_out==1) { print "$elem"; }
  if (defined($new_file)) { print OUTPUT "$elem"; }
  if ($send_mail==1) { print $MAIL "$elem"; }
}

if (defined($new_file)) { close (OUTPUT); }
if ($send_mail==1) { $MAIL->close; }
close (PFSTAT) and unlink($path_to_pfstat);


} # Ende von keine_Hilfe
