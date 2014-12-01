#!/usr/bin/perl -w

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

###############################################
### Dieses Skript soll Dateien von folgendem Format entpacken, einlesen und an
### eine vorher definierte Datei anhaengen. Format: mail-yyyymmdd
###
### Um das Start- und Enddatum ermitteln zu koennen wird dies ueber die
### Parameter -s fuer Start- und -e fuer Enddatum uebergeben.
### Bsp: send_Spam_Stats.pl -s 20060220 -e 20060101
###
### Alternativ kann die Differenz (-d) in Tagen uebergeben werden, wobei das 
### Startdatum alternativ angegeben werden kann.
### Bsp: send_Spam_Stats.pl -s 20060220 -d 20
### Bsp: send_Spam_Stats.pl -d 20
###
###############################################

use strict;
use Getopt::Std;
use Date::Manip;
use MIME::Lite;
use Sys::Hostname;
use POSIX qw(strftime);
use File::Temp qw(tempfile);

## Deklaration von Variablen
my ($start, $end, $delta, $tmpfile, $fh);
my $progname    = 'send_Spam_Stats.pl';

my $PATH_TO_LOG = '/var/log/old/';
my $TMP_PATH    = '/var/tmp/';
my $PREFIX      = 'amavis';

my $mailmon     = 'mailmon@example.comf';
my $from        = 'spam-stats@example.com';
my $host        = hostname;
my $date        = strftime "%d.%m.%Y", localtime;
my $amavislogsumm_options = '-h 20';


my $helptext="Dieses Skript startet amavislogsumm fuer mehrere Tage.\n"
      ."Sie koennen folgende Optionen beim Aufruf verwenden:\n"
      ."\t-h ...zeigt diesen Text an\n"
      ."\t-p <Pfad>       ...Amavis Logdateien liegen im <Pfad>\n"
      ."\t\t\t   (default: $PATH_TO_LOG)\n"
      ."\t-s <Startdatum> ...legt das Startdatum (yyyymmdd) fest\n"
      ."\t-e <Enddatum>   ...legt das Enddatum (yyyymmdd) fest\n"
      ."\t-d <Differenz>  ...vom Startdatum wird um <Differenz> zurueckgerechnet\n"
      ."\t\t\t   und bis dahin das Logfile ausgewertet.\n"
      ."\t\t\t   Ist s nicht definiert wird es auf today gesetzt.\n\n";

getopt('sedp');	# Benutze Parameter -s, -e, -d, -f, -p
getopts('h');		# Benutze Flag -h
our ($opt_s, $opt_e, $opt_d, $opt_h, $opt_p);
if (defined($opt_s)) { $start=$opt_s; } else { $start=0; }
if (defined($opt_e)) { $end=$opt_e; } else { $end=0; }
if (defined($opt_d)) { $delta=$opt_d; } else { $delta=0; }
if (defined($opt_p)) { $PATH_TO_LOG=$opt_p; }
if (defined($opt_h))
{
   print $helptext;
   exit 0;
}

# Ueberpruefe, ob die Parameterangaben sinnvoll sind 
if ($delta!=0 && $end!=0)
{
  print "Die Parameter e und d koennen nicht gleichzeitig verwendet werden!\n";
  print "Skript Abbruch!\n\n";
  exit 5;
} 

if ($delta==0 && $start!=0 && $end==0)
{
  print "Es muss noch d oder e als Parameter angegeben werden.\n";
  print "Skript Abbruch!\n\n";
  exit 5;
}

if ($delta<0 || $start<0 || $end<0)
{
  print "Den Parametern muss ein Wert groesser als Null uebergeben werden.\n";
  print "Skript Abbruch!\n\n";
  exit 5;
}

## Die Differenz auswerten:
# Debugausgaben
#print "Start: $start \n";
#print "End:   $end \n";
#print "Delta: $delta \n";

## Der Startparameter existiert immer. Wenn er nicht angegeben wird ist er Null
if ($start==0)
{ 
   $start = UnixDate(DateCalc("today", "0 days"), "%Y%m%d");
}else
{
   ## Ist der uebergebene Wert ein Datum und hat das entsprechende Format?
   ## Diese Ueberpruefung ist nur oberflaechlich!
   my $lookup = ParseDate($start);
   #print "Lookup: $lookup\n\n";
   if ((! $lookup) || ($start<10000000))
   {
     #print "lookup: $lookup\n";
     print "Das uebergebene Datum hatte kein korrektes Format (yyyymmdd)!\n";
     print "Skript Abbruch!\n\n";
     exit 5;
   }
}

## Erstelle eine temporäre Datei in dem Ordner $TMP_PATH
($fh, $tmpfile) = tempfile(DIR => $TMP_PATH, UNLINK => 1);
close($fh);


## Ist kein d angegeben, dann muss ein e existieren
if ($delta==0)
{
   ## Ist der uebergebene Wert ein Datum und hat das entsprechende Format?
   ## Diese Ueberpruefung ist nur oberflaechlich!
   my $lookup = ParseDate($end);
   #print "Lookup: $lookup\n\n";
   if ((! $lookup) || ($end<10000000))
   {
     #print "lookup: $lookup\n";
     print "Das uebergebene Datum hatte kein korrektes Format (yyyymmdd)!\n";
     print "Skript Abbruch!\n\n";
     exit 5;
   }

   ## Liegt der Startwert zeitlich nach dem Endwert?
   my $date1 = ParseDate($start);
   my $date2 = ParseDate($end);
   my $flag = Date_Cmp($date1,$date2);
   if ($flag<0)
   {
     # date1 is earlier
     print "Das Startdatum muss juenger als das Enddatum sein!\n";
     print "Skript Abbruch!\n\n";
     exit 5;
   }

   ## Die Uebergebenen Werte sind wahrscheinlich richtig.
   ## Der Schleifendurchlauf kann beginnen.
   my $date = UnixDate(DateCalc($end, "-1 days"), "%Y%m%d");
   do
   {
      ## Erhoehe das Datum um einen Tag.
      $date = UnixDate(DateCalc($date, "1 days"), "%Y%m%d");
      ## Entpacke das logfile und haenge es an die Temp-Datei.
      if (-r "$PATH_TO_LOG/$PREFIX-$date.gz") {
         system "gunzip -c $PATH_TO_LOG/$PREFIX-$date.gz >> $tmpfile";
      } else {
         system "cat $PATH_TO_LOG/$PREFIX-$date >> $tmpfile";
      }
      #print "date: $date\n";
   } until ($start == $date);
}else
{
   ## Es existiert ein Delta (d), damit kann in einer Schleife einfach
   ## zurueck gezaehlt werden.
   ## Zaehle von Start - (Delta-1) bis Start
   for (my $i=$delta-1; $i>=0; $i--)
   {
      my $date = UnixDate(DateCalc($start, "-$i days"), "%Y%m%d");
      ## Entpacke das logfile und haenge es an die Temp-Datei.
      if (-r "$PATH_TO_LOG/$PREFIX-$date.gz") {
         system "gunzip -c $PATH_TO_LOG/$PREFIX-$date.gz >> $tmpfile";
      } else {
         system "cat $PATH_TO_LOG/$PREFIX-$date >> $tmpfile";
      }
      #print "$date \n";
   }
}


## amavislogsumm.pl wird aufgerufen und mit den Daten aus $TMP_FILE gefüttert

my $output = `/usr/sbin/amavislogsumm $amavislogsumm_options < $tmpfile`;

if ($output) {
   my $msg = MIME::Lite->new(
      From    => $from,
      To      => $mailmon,
      Subject => "SPAM-STATISTIKEN vom $date",
      Type    => 'text/plain',
      Data    => "Statistiken wurden erstellt von: $host" ."\n" ."$output",
   );
   $msg->send;
} else {
   print "error: no report generated by amavislogsumm!";
}

unlink($tmpfile);
