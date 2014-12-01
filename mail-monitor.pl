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

# parse a message from 'sendmail -bv myuser@domain' to check if it
# is deliverable or not.
# Create a user monitor; create the file /home/monitor/.forward:
# |/usr/local/bin/mail-monitor.pl
# (this scirpt)
# Execute the 'sendmail -bv' command as the monitor user.
# Get a file with the recipients name if the message is deliverable.

use strict;
use warnings;

my $ThisLine;
my $status_path = '/home/monitor/';
my $rcpt;


while (defined($ThisLine = <STDIN>)) {
   chomp($ThisLine);

   # get recipient
   if ($ThisLine =~ /^Final-Recipient: rfc822; ([\S]*)$/) {
      $rcpt = "$1";
   }
   if ($ThisLine =~ /^Action: deliverable$/ and defined($rcpt)) {
      open FILE, ">$status_path/$rcpt" or die $!;
      print FILE 'OK';
      close FILE;
   }
   # Final-Recipient: rfc822; user@example.com
   # Action: deliverable
   # Status: 2.1.5
   # Remote-MTA: dns; mx.example.com
   # Diagnostic-Code: smtp; 250 2.1.5 Ok

   # Final-Recipient: rfc822; nouser@example.com
   # Action: undeliverable
   # Status: 4.0.0
   # Diagnostic-Code: X-Postfix; delivery via local: user lookup error
}
