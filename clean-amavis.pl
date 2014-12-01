#!/usr/bin/perl -w

# clean-amavis.pl
#####################################################################
# Copyright (c) 2014 Stefan Jakobs
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
# Description:
# This script will clean up amavisd-new's MySQL tables by:
# - removing all records from tables msgs, msgrcpt, quaratine and
#   maddr which are not part of this partition/week or the last
#   partition/week
#
# Before running this script set the variables $DB_* and $days 
# according to your setup.
# The verbosity is configurable by setting the variable $debug:
# - $debug = 0: only errors will be reported
# - $debug = 1: a short summery will be reported
# - $debug = 2: all deleted records will be reported
#
#####################################################################

use strict;
use DBI;
use POSIX;

# set these variables according to your setup:
my $DB_HOST = 'vdbwr.example.com';
my $DB_NAME = 'amavis';
my $DB_USER = 'amavisd';
my $DB_PASS = 'secret';
# set to 1 to print a simple report; 2 to be verbose
my $debug = 1;

# other variables;
my $cursor;
my %cnt_old_msgs;
my $output = "";

# mysql connect
my $dbh = DBI->connect("DBI:mysql:$DB_NAME:$DB_HOST", $DB_USER, $DB_PASS, 
			{RaiseError => 1, AutoCommit => 1} ) 
			or die $DBI::errstr;

# get current week
my $current_week = POSIX::strftime("%V", gmtime time);
my $seven_days_ago = time - 7*24*3600;
my $last_week = POSIX::strftime("%V", gmtime $seven_days_ago);

# count and then remove records which are not from the current or last week
foreach(('msgs', 'msgrcpt', 'quarantine', 'maddr')) {
   my $sql = "SELECT COUNT(*) FROM $_ WHERE partition_tag != $last_week AND partition_tag != $current_week";
   $cursor = $dbh->prepare($sql);
   $cursor->execute() or die $dbh->errstr;
   $cnt_old_msgs{"$_"} = $cursor->fetchrow;
   $cursor->finish;
   if ($cnt_old_msgs{"$_"} > 0) {
      if ($debug > 0) {
         $output .= "\nremoved $cnt_old_msgs{$_} rows from $_ that are != week $last_week and != week $current_week.\n";
      }
      if ($debug > 1) {
         $cursor = $dbh->prepare("SELECT * FROM $_ WHERE partition_tag != $last_week AND partition_tag != $current_week");
         $cursor->execute() or die $dbh->errstr;
         while ( my @row = $cursor->fetchrow_array ) {
            foreach (@row) { 
               if (!defined($_)) { $_ = ' '; }
            }
            $output = $output . "   @row\n";
         }
         $cursor->finish;
      }
   }
   $cursor = $dbh->prepare("DELETE FROM $_ WHERE partition_tag != $last_week AND partition_tag != $current_week");
   $cursor->execute() or die $dbh->errstr;
}


# disconnect
$dbh->disconnect;

# print output
if (keys %cnt_old_msgs) {
   print $output;
}
