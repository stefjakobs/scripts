#!/usr/bin/perl -w

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

# Description:
# parse the logfile of an IPSwitch iMail Server and count how many
# users have used imap or pop3.

use strict;

my $ThisLine;
my ($date, $hour, $service, $user);
my (%result, %users);

while (defined($ThisLine = <STDIN>)) {
   chomp($ThisLine);

   if ( ($date, $hour, $service, $user) = ($ThisLine =~ m/(\d\d:\d\d) (\d\d):\d\d (IMAP4|POP3D)  \([0-9A-F]{8}\) .*logon success for (\S+)/) ) {
      $hour = $hour + 0;
      $result{$hour}{$service}{$user}++;
      $users{$user}++;
   }
}

my %sum;

foreach my $h (sort {$a cmp $b} keys %result) {
#   printf("$h:\n");
   foreach my $s (sort {$a cmp $b} keys %{$result{$h}}) {
#      printf("    %s:\n", $s);
      foreach my $u (sort {$a cmp $b} keys %{$result{$h}{$s}}) {
#         printf("\t%-40s %5d\n", $u, $result{$h}{$s}{$u});
         $sum{logins} += $result{$h}{$s}{$u};
      }
   }
}

print "\nSUMMARY:\n\n";
printf("  users logged in: %5d\n", scalar(keys %users));
printf("  overall logins: %5d\n", $sum{logins});
print "\n";
print ("| Hour | service | # users | # logins |\n");
for (my $i=0; $i<24; $i++) {
   foreach my $s (keys %{$result{$i}}) {
      my $logins = 0;
      foreach my $u (keys %{$result{$i}{$s}}) {
         $logins += $result{$i}{$s}{$u};
      }
      printf("|   %2d | %7s | %7d | %8d |\n", $i, $s, scalar(keys %{$result{$i}{$s}}), $logins);
   }
}
