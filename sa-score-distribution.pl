#!/usr/bin/perl -w -T

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

use strict;
use Getopt::Long;
use Pod::Usage;
use Math::Round;

my $ThisLine;
my ($help, $man, $debug);
my $start = 0;
my $end = 10;
my @rulelist;
my @disabled_rules;
my %hits;
my %scores;
my %adjusted_hits;
my %rule_score_list;
my $precision = 0;



#### MAIN ####

GetOptions(
   'help|?'        => \$help,
   'man'           => \$man,
   'rule|r=s'      => \@rulelist,
   'start|s=s'     => \$start,
   'disable|b=s'   => \@disabled_rules,
   'precision|p'   => sub{ $precision++; },
   'end|e=s'       => \$end,
   'debug|d'       => \$debug,
) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

@rulelist = split(/,/,join(',',@rulelist));
@disabled_rules = split(/,/,join(',',@disabled_rules));

while (defined($ThisLine = <STDIN>)) {
   chomp($ThisLine);

   # Nov 21 00:06:00 hydra amavis[2304]: (02304-08) spam-tag, <info@example.com> -> <user@example.org>, Yes, score=69.444 tagged_above=-999 required=5 tests=[ADVANCE_FEE_5_NEW_MONEY=0.507, AXB_XMAILER_MIMEOLE_OL_024C2=3.237, BAYES_99=3.5, BAYES_999=4.5, DCC_CHECK=1.1, ...
   if ($ThisLine =~ /spam-tag, <[^<>]+> -> <[^<>]+>, (?:Yes|No), score=([-0-9.]+) tagged_above=[-0-9.]+ required=[-0-9.]+ tests=\[((?:[A-Z0-9_]+=[-0-9.]+, )+)/) {
      my @rulelist = split(', ', $2);
      my $score = sprintf("%.${precision}f", "$1"); #round($1);
      my $adjusted_score = $score;
      $hits{$score}++;
      foreach my $r (@rulelist) {
         my $quantitiy;
         my $rule;
         # separate rule and score.
         if ($r =~ /([A-Z0-9_]+)=([-0-9.]+)/) {
            $rule = $1;
            $quantitiy = $2;
         
            ### TODO: some rules may have up to four scores. How should that be handled?
            #if (defined($rule_score_list{$rule}) and $rule_score_list{$rule} != $quantitiy) {
            #   $rule = "${rule}-${quantitiy}";
            #   print "warning: rename rule!\n";
            #}
            $rule_score_list{$rule} = $quantitiy;
            $scores{$score}{$rule}++;

            if (@disabled_rules) {
               foreach my $dr (@disabled_rules) {
                  if ($rule eq $dr) {
                     $adjusted_score -= $rule_score_list{$rule};
                  }
               }
            }

         } else {
            print "warning: could not separate rule from score!\n";
         }
      }
      my $new_adjusted_score = sprintf("%.${precision}f", "$adjusted_score");
      $adjusted_hits{$new_adjusted_score}++;
   }
}

## report ##

if (@rulelist) {
   print "score distribution of rule(s):\n";
   printf "  %4s  %8s  ", 'score', 'hits';
   if (@disabled_rules) { printf "%10s ", 'hits r.d.'; }
   foreach (@rulelist) { printf "%20s ", "$_ ($rule_score_list{$_})"; }
   print "\n";
   for(my $score=$start; $score <= $end; $score = $score + 10 ** -${precision}) {
      $score = sprintf("%.${precision}f", "$score");
      printf "  %-5.${precision}f  %8i  ", $score, $hits{$score} ? $hits{$score} : 0;
      if (@disabled_rules) { printf "%10i  ", $adjusted_hits{$score} ? $adjusted_hits{$score} : 0; }
      foreach my $r (@rulelist) {
         printf "%20i ", $scores{$score}{$r} ? $scores{$score}{$r} : 0;
      }
      print "\n";
   }
} else {
   print "which rules have matched at which score:\n";
   foreach my $score (sort {$a <=> $b} keys %scores) {
      if ($score >= $start and $score <= $end) {
         printf "  %8i       %s\n", $scores{$score}, $score;
         foreach my $rule (sort {$scores{$score}{$b} <=> $scores{$score}{$a}} keys %{$scores{$score}}) {
            printf "    %6i         %s\n", $scores{$score}{$rule}, $rule;
         }
      }
   }
}


__END__

=head1 NAME

print all sa-rules which hit at which score value.

=head1 SYNOPSIS

sa-score-distribution.pl [options] < amavis-log-file

Options:
   -help          brief help message

   -man           full documentation

   -rule          print score distribution of this rule only

   -start         limit the output: score >= start value (default: 0)

   -end           limit the output: score <= end value (default: 0)

   -precision     show score in X steps (default: 10 ** -X | X=0)

   -disable       calculate hit ratio with rules disabled

   -debug         enable debug output

=head1 OPTIONS

=over 8

=item B<amavis-log-file>

read amavis log file via STDIN.

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-rule>

print at which score the named rule(s) had hit. A comma separated
list ist accepted.

=item B<-start>

limit the output: score >= start value (default: 0)

=item B<-end>

limit the output: score <= end value (default: 0)

=item B<-precision>

steps in which the scores will be separated. Steps will be calculated
with 10 to the power of X. Where X is 0, 1 or 2.

=item B<-disable>

calculate the hit ratio if the named rules are set to zero.

=back

=head1 DESCRIPTION

This script will print a list of all rules that hit at a specific
score value.

=head1 EXAMPLE

# sa-score-distribution.pl < amavis  | head
rules which have matched at this score

   7821016       5
       192         SA2DNSBLC
       179         HTML_MESSAGE
       153         DCC_CHECK
       104         BAYES_50
        93         MIME_HTML_ONLY
        73         SPF_PASS
        64         RCVD_IN_DNSWL_NONE

# sa-score-distribution.pl -s '-5' -rule DCC_CHECK,IXHASH_X1 < amavis 
score distribution of rule(s):
  score      hits             DCC_CHECK            IXHASH_X1 
    -5       951                   445                    2 
    -4      2437                    56                    0 
    -3       966                   441                    1 
    -2      7640                   251                    0 
    -1      6092                   649                    7 
     0      7784                  4364                   20 
     1       891                   575                   18 
     2       545                   401                   50 
     3       338                   207                   13 
     4       466                   353                   84 
     5       251                   183                   43 
     6       286                   194                   62 
     7       354                   300                   42 
     8       277                   211                   38 
     9       340                   302                   53 
    10       254                   208                   67

=cut

