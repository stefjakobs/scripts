#!/usr/bin/perl -w

# Copyright (c) 2014 Stefan Jakobs <project AT localside.net>
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

# This script connects to a SMTP server and sends a message to the
# specified recipients

use strict;
use Net::SMTP;
use Sys::Hostname;
use Getopt::Long;
use Pod::Usage;
use Date::Manip;

# variables
my $help    = 0;
my $man     = 0;
my $server  = '';
my $port    = 25;
my $helo    = hostname();
my $from    = 'auser@example.com';
my @to      = ();
my $debug   = 0;
my $bits    = 0;
my @goodrcpts;
my $today   = UnixDate(ParseDate("now"), "%a, %d %b %Y %H:%M:%S +0200 (CEST)");

# main
GetOptions(
   'help|?'       => \$help,
   'man'          => \$man,
   'helo|h=s'     => \$helo,
   'from|f=s'     => \$from,
   'to|t=s'       => \@to,
   'debug|d'      => \$debug,
   '7bit|7'       => sub { $bits = 7 },
   '8bit|8'       => sub { $bits = 8 },
) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
@to = split(/,/,join(',',@to));
$server = shift @ARGV;

## check options
pod2usage(1) if not $server;
if (! @to) {
   printf "error: no recipients\n";
   exit(1);
}

my $smtp = Net::SMTP->new($server, Hello => $helo, Debug => $debug);

if ($bits == 0) {
   $smtp->mail($from);
} else {
   $smtp->mail($from, Bits => "$bits" );
}
@goodrcpts = $smtp->to(@to, { SkipBad => 1 });

if ($#goodrcpts >= 0) { 
   $smtp->data( );

   $smtp->datasend("To: @to\n");
   $smtp->datasend("From: <$from>\n");
   $smtp->datasend("Date: $today\n");
   $smtp->datasend("Subject: A message from my Perl program.\n");
   $smtp->datasend("Content-Type: text/plain; charset=\"utf-8\"\n");
   $smtp->datasend("\n");
   $smtp->datasend("This is just an example message.\n");
   $smtp->datasend("Ein paar Ümlaute: üäö.\n");

   $smtp->dataend( );
}

$smtp->reset();
if ($smtp->quit()) {
   # print summary
   if ($#goodrcpts >= 0) {
      print "Message\n";
      foreach my $r (@goodrcpts) {
         printf "  send to: %-s\n", $r;
      }
   } else {
      print "Message wasn't send: No valid recipients!";
   }
   print "\n";
}

__END__

=head1 NAME

Connect to a SMTP server and sends an example message.

=head1 SYNOPSIS

send-mail.pl [options] SMTP-SERVER

Options:
   -help          brief help message
   -man           full documentation
   -helo          use this string to greet the server
   -from          use this address as envelope from (mail from:).
   -to            use this address as envelope to (rcpt to:)
   -7bit          enable 7 Bit transmission
   -8bit          enable 8 Bit MIME encoding 
   -debug         enable debug output

=head1 OPTIONS

=over 8

=item B<SMTP-SERVER>

connect to this server, e.g. send-mail.pl -to user@example.net mail.example.com.

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-helo>

Use this string to greet the SMTP server, e.g. -helo myserver.example.net.

=item B<-from>

Use this sting as envelope from address (mail from:), e.g. -from 
myuser@example.net.

=item B<-to>

Use this sting as envelope to address (rcpt to:). This options may be set
multiple times and/or address can be comma separated, e.g. -to 
john.doe@example.com,jd@example.com.

=item B<-7bit>

enable 7 Bit transmisson.

=item B<-8bit>

enable 8 Bit transmisson.

=item B<-debug>

enable debug output.

=back

=head1 DESCRIPTION

B<send-mail.pl> connects to a given host on SMTP port (25) and sends
an example message. If the sending was successfull the script prints
the a list of the recipients.

=cut

