#!/usr/bin/perl

use strict;

######
# count_bounces.pl
# This Script works line by line through a Postfix logfile and counts the
# amount of mails which a server has send but have bounced.
#
######
# Copyright (c) 2009-2014 Stefan Jakobs
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
#####################################################################
# Version and last change date:
my $Version = 0.1;
my $VDate = '18/03/09'; # MM/DD/YY
#
#####################################################################
# This was written by:
# 	Stefan Jakobs <project AT localside.net>
#
#####################################################################
my $ThisLine = "";
my @ID_list;
my (%IDS, %rcptserv, %client, %bouncelist, %bouncemessage, %allrcptserv);

while (defined($ThisLine = <STDIN>)) {
  chomp($ThisLine);
  $ThisLine =~ s/^[A-Za-z]{3} [0-9]{2} (?:[0-9]{2}:){2}[0-9]{2} \w* //;

  if ($ThisLine =~ /^postfix\/(?:smtp|smtpd|bounce|lmtp)/)
  {
    if ($ThisLine =~ /^postfix\/smtp\[[0-9]{1,5}\]: ([A-Z0-9]{10,11}): to\=<.*>, relay\=(.*),?.*, delay\=.*, status\=bounced/) 
    {
      $rcptserv{$1} = $2;
      push(@ID_list, $1);
      $bouncelist{$client{$IDS{$1}}}++;
      #print $2;
    }

    if ($ThisLine =~ /^postfix\/smtp\[[0-9]{1,5}\]: ([A-Z0-9]{10,11}): to\=<.*>, relay\=(.*),?.*, delay\=.*, status\=/) 
    {
      $allrcptserv{$1} = $2;
    }

    elsif ($ThisLine =~ /^postfix\/bounce\[[0-9]{1,5}\]: ([A-Z0-9]{10,11}): sender non-delivery notification: ([A-Z0-9]{10,11})$/)
    {
      $bouncemessage{$1} = $2;
    }

    elsif ($ThisLine =~ /^postfix\/lmtp\[[0-9]{1,5}\]: ([A-Z0-9]{10,11}): to\=<.*>, relay\=.*, status\=sent \(250 2\.0\.0 Ok: queued as ([A-Z0-9]{10,11})\)$/)
    {
      $IDS{$2} = $1;
      #print "$1 -> $2";
    }

    elsif ($ThisLine =~ /^postfix\/smtpd\[[0-9]{1,5}\]: ([A-Z0-9]{10,11}): client=(.*)$/)
    {
      $client{$1} = $2;
    }

  }
}

## results

print "Bounces gingen an:\n";
foreach (keys %bouncemessage) {
  printf "%60.60s->\t %s\n", $client{$IDS{$_}}, $allrcptserv{$bouncemessage{$_}}; 
}
print "\n\n\n";

foreach (@ID_list) {
  printf "%60.60s->\t %s\n", $rcptserv{$_}, $client{$IDS{$_}};
}

my @sorted_bouncelist = sort { $bouncelist{$a} <=> $bouncelist{$b} } keys %bouncelist;
print "\n";
foreach (@sorted_bouncelist) {
  printf "\n%60.60s\t%5i Bounce(s)", $_, $bouncelist{$_};
}
print "\n";
