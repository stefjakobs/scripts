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


use strict;
use Mail::IMAPClient;

if ($#ARGV != 0) {
   print "usage: imapexpunge.pl <user>\n";
   exit 1;
}

my $user = $ARGV[0];

my $imap = Mail::IMAPClient->new(
   Server   => 'localhost',
   User     => $user,
   Password => '',
) or die "Cannot connect: $@";

my $folders = $imap->folders or die "List folders error: ", $imap->LastError, "\n";
#print "Folders: @$folders\n";

foreach my $folder (@$folders) {
  $imap->select($folder) or die "Select '$folder' error: ", $imap->LastError, "\n";
  if ($imap->expunge($folder)) {
     print "Expange '$folder' successfull\n";
  } else { 
    die "Expange '$folder' error: ", $imap->LastError, "\n";
  } 
}

$imap->logout or die "Logout error: ", $imap->LastError, "\n";
