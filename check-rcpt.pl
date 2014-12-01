#!/usr/bin/perl -w
#
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

# This script connects to a SMTP server and issues ehlo, mail from:,
# and rcpt to: commands to test that server.

use strict;
use Net::SMTP;
use Sys::Hostname;
use Getopt::Long;
use Pod::Usage;

# variables
my $help       = 0;
my $man        = 0;
my $server     = '';
my $port       = 25;
my $helo       = hostname();
my $from       = 'auser@example.com';
my @to         = ();
my $debug      = 0;
my $quiet      = 0;
my $bits       = 0;
my $exp_reject = 0;
my $status     = 0;
my @goodrcpts;
my @badrcpts;

# main
GetOptions(
   'help|?'          => \$help,
   'man'             => \$man,
   'helo|h=s'        => \$helo,
   'from|f=s'        => \$from,
   'to|t=s'          => \@to,
   'debug|d'         => \$debug,
   'quiet|q'         => \$quiet,
   'expect-reject|r' => \$exp_reject,
   '7bit|7'          => sub { $bits = 7 },
   '8bit|8'          => sub { $bits = 8 },
) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
@to = split(/,/,join(',',@to));
if (not @to) { $to[0] = $from; }

$server = shift @ARGV;
pod2usage(1) if not $server;
## check options
# bits = 7|8 ...

print "connecting to $server: $port ...\n" if not $quiet;

my $smtp = Net::SMTP->new($server, Hello => $helo, Debug => $debug) or die 'can not create new server object';

if ($bits == 0) {
   $smtp->mail($from);
} else {
   $smtp->mail($from, Bits => "$bits" );
}
@goodrcpts = $smtp->to(@to, { SkipBad => 1 });
foreach my $rcpt (@to) {
   if ( ! grep {$rcpt eq $_} @goodrcpts ) {
      push(@badrcpts, $rcpt)
   }
}

#$smtp->data( );

#$smtp->datasend("To: @to\n");
#$smtp->datasend("Subject: A message from my Perl program.\n");
#$smtp->datasend("\n");
#$smtp->datasend("This is just an example message.\n");

#$smtp->dataend( );

$smtp->reset();
$smtp->quit();

# print summary
if (not $quiet) {
   print "\n";
   print "server    :     " . $smtp->banner();
   print "helo      :     " . $helo ."\n";
   print "mail from :     " . $from ."\n";
}
foreach my $r (@to) {
   if ($exp_reject) {
      # list bad rcpts as OK
      if (grep {$r eq $_} @badrcpts) {
         printf "rcpt to   : OK  %-s\n", $r if not $quiet;
      } else {
         printf "rcpt to   :     %-s\n", $r if not $quiet;
         $status++;
      }
   } else {
      # list good rcpts as OK
      if (grep {$r eq $_} @goodrcpts) {
         printf "rcpt to   : OK  %-s\n", $r if not $quiet;
      } else {
         printf "rcpt to   :     %-s\n", $r if not $quiet;
         $status++;
      }
   }
}
print "\n" if not $quiet;
exit $status

__END__

=head1 NAME

Connect to a SMTP server and send helo, mail from: and rcpt to:.

=head1 SYNOPSIS

check-rcpt.pl [options] SMTP-SERVER

Options:
   -help          brief help message
   -man           full documentation
   -helo          use this string to greet the server
   -from          use this address as envelope from (mail from:).
   -to            use this address as envelope to (rcpt to:)
   -7bit          enable 7 Bit transmission
   -8bit          enable 8 Bit MIME encoding 
   -quiet         suppresses output (except debug output if enabled)
   -debug         enable debug output

=head1 OPTIONS

=over 8

=item B<SMTP-SERVER>

connect to this server, e.g. check-rcpt.pl mail.example.com.

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

=item B<-quiet>

suppress status and results output. Debug output will be printed if
enabled.

=item B<-debug>

enable debug output.

=item B<-expect-reject>

The expected behaviour of the SMTP server is to reject the recipient.
Accepting the message will cause the script to fail.

=back

=head1 DESCRIPTION

B<check-rcpt.pl> will be used to test a SMTP server. It will connect to
a given host on SMTP port (25) and issue the commands: ehlo, mail from:
and rcpt to:. After the connection has been terminated it will print a
summary which lists the rejected and accepted (OK) recipient addresses.

=cut

