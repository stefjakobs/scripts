#!/usr/bin/perl -w 
#
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


# This script creates an ics calendar file (RFC2445) with
# recurring events and todos. Used for test cases.

use strict;
use Data::ICal;
use Data::ICal::Entry::Event;
use Data::ICal::Entry::Todo;
use Data::ICal::Entry::TimeZone;
use Data::ICal::Entry::TimeZone::Standard;
use Data::ICal::Entry::TimeZone::Daylight;
use Data::ICal::Entry::Todo;
use Getopt::Long;
use Date::Manip;
use Pod::Usage;
use Date::Calc qw/Add_Delta_Days Add_Delta_DHMS Add_Delta_YMDHMS Today Today_and_Now Localtime/;

# predefine variables
my $help        = 0;
my $man         = 0;
my $organizer   = "CN=\"John Joe\":MAILTO:john.joe\@example.com";
my $description = "An event";
my $summary     = "Event summary";
my $location    = "New York";
my $start       = UnixDate(ParseDate("today"), "%d.%m.%Y 14:00:00");
my $repeat      = 3;
my $interval    = '1h';
my $period      = '2h';
my $opaque      = 0;
my @tr_op       = ("TRANSPARENT", "OPAQUE");
my $todostart   = UnixDate(ParseDate("today"), "%d.%m.%Y 14:00:00");
my $tododescription = "A Todo";
my $todosummary = 'Todo Summary';
my $priority    = 5;
my $complete    = 0;
my $todoperiod  = '5D';
my $tzid        = "Europe/Berlin";
my $today_now   = sprintf( '%04d%02d%02dT%02d%02d%02dZ', Today_and_Now() );
my $calendar    = Data::ICal->new();
my $tz          = Data::ICal::Entry::TimeZone->new();
my $daylight    = Data::ICal::Entry::TimeZone::Daylight->new();
my $standard    = Data::ICal::Entry::TimeZone::Standard->new();

# functions
sub parse_date {
   my $date_string = shift @_;
   my @date;

   if ($date_string =~ /^(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{4}) (\d{2}):(\d{2}):(\d{2})$/) {
      @date = ( $3, $2, $1, $4, $5, $6);
   } else {
      print "error: failed to parse date string\n";
      exit 1;
   }
   return @date;
}

sub parse_delta_date {
   my $date_string = shift @_;
   my %date = (0 => 'Y', 1 => 'M', 2 => 'D', 3 => 'h', 4 => 'm', 5 => 's');
   my @delta_date;

   foreach my $key (keys %date) {
      if ($date_string =~ /(\d+)$date{$key}/) {
         $delta_date[$key] = $1;
      } else {
         $delta_date[$key] = 0;
      }
   }
   return @delta_date;
}
# create calendar object
$calendar->add_properties( 'X-CALNAME' => 'Test Calendar' );

# create timezone object
$tz->add_properties( tzid => "Europe/Berlin" );

# create daylight and standard objects and add them to timezone
$daylight->add_properties(
   'tzname'       => 'CEST',
   'tzoffsetfrom' => '+0100',
   'tzoffsetto'   => '+0200',
   'dtstart'      => '19810329T020000',
   'rrule'        => 'FREQ=YEARLY;BYDAY=-1SU;BYMONTH=3'
);
$tz->add_entry($daylight);
$standard->add_properties(
   'tzname'       => 'CET',
   'tzoffsetfrom' => '+0200',
   'tzoffsetto'   => '+0100',
   'dtstart'      => '19800928T030000',
   'rrule'        => 'FREQ=YEARLY;COUNT=16;BYDAY=-1SU;BYMONTH=9'
);
$tz->add_entry($standard);
$standard = Data::ICal::Entry::TimeZone::Standard->new();
$standard->add_properties(
   'tzname'       => 'CET',
   'tzoffsetfrom' => '+0200',
   'tzoffsetto'   => '+0100',
   'dtstart'      => '19961027T030000',
   'rrule'        => 'FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10'
);
$tz->add_entry($standard);

# add timezone to calendar
$calendar->add_entry($tz);


# main
GetOptions(
   'help|?'        => \$help,
   'man'           => \$man,
   'organizer=s'   => \$organizer,
   'description=s' => \$description,
   'summary=s'     => \$summary,
   'location=s'    => \$location,
   'start=s'       => \$start,
   'repeat=s'      => \$repeat,
   'interval=s'    => \$interval,
   'period=s'      => \$period,
   'opaque'        => \$opaque,
   'todo-start=s'  => \$todostart,
   'todo-description=s' => \$tododescription,
   'todo-summary=s'     => \$todosummary,
   'priority=i'    => \$priority,
   'todo-period=s'  => \$todoperiod,
   'complete=i'    => \$complete,
) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

## add events:
my @dtstart = parse_date($start);
my @delta_interval = parse_delta_date($interval);
my @delta_period = parse_delta_date($period);

for(my $i = 0; $i < $repeat; $i++){
   my @dtend   = Add_Delta_YMDHMS(@dtstart, @delta_period);
   my $vevent = Data::ICal::Entry::Event->new();
   $vevent->add_properties(
      created 		    => $today_now,
      organizer		 => $organizer,
      dtstamp		    => $today_now,
      'last-modified' => $today_now,
      description 	 => $description,
      summary 		    => $summary . " " . $i,
      location		    => $location . " " . $i,
      "dtstart"       => [ sprintf( '%04d%02d%02dT%02d%02d%02dZ', @dtstart ),
		   { 'TZID' => $tzid } ],
      "dtend"         => [ sprintf( '%04d%02d%02dT%02d%02d%02dZ', @dtend ),
         { 'TZID' => $tzid } ],
      transp          => $tr_op[$opaque],
   );
   @dtstart = Add_Delta_YMDHMS(@dtstart, @delta_interval);
   $calendar->add_entry($vevent);
}

## Add todos:
@dtstart = parse_date($todostart);
#@delta_interval = parse_delta_date($todointerval);
@delta_period = parse_delta_date($todoperiod);

for(my $i = 0; $i < $repeat; $i++){
   my @due    = Add_Delta_YMDHMS(@dtstart, @delta_period);
   my $vevent = Data::ICal::Entry::Todo->new();
   $vevent->add_properties(
      created         => $today_now,
      organizer       => $organizer,
      dtstamp         => $today_now,
      'last-modified' => $today_now,
      description     => $tododescription,
      summary         => $todosummary . " " . $i,
      dtstart         => [ sprintf( '%04d%02d%02dT%02d%02d%02dZ', @dtstart ),
         { 'TZID' => $tzid } ],
      due             => [ sprintf( '%04d%02d%02dT%02d%02d%02dZ', @due ),
         { 'TZID' => $tzid } ],
      priority        => $priority,
      'percent-complete' => $complete,
   );
   @dtstart   = Add_Delta_YMDHMS(@dtstart, @delta_interval);
   $calendar->add_entry($vevent);
}

print $calendar->as_string;


__END__

=head1 NAME

create an ics Calendar file with events and todos.

=head1 SYNOPSIS

create-ics.pl [options]

Options:
   -help            brief help message
   -man             full documentation
   -organizer       events' organizer
   -description     events' description
   -summary         events' summary
   -location        events' location
   -start           events' start date and time
   -repeat          event repeatition
   -interval        interval between two events and/or todos
   -period          period of one event
   -opaque          events are opaque
   -todo-start      todo's start
   -todo-description  todo's description
   -todo-summary    todo's summary
   -priority        todo's priority
   -todo-period      todo's period to due
   -complete        X percent of todo is completed

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-organizer>

Set the events' organizer, e.g. CN="John Jones":MAILTO:jj@exmaple.com".

=item B<-description>

Set the events' description.

=item B<-summary>

Set the events' summary.

=item B<-location>

Set the events' location.

=item B<-start>

Set the events' start date and time. See DATE AND TIME section for its syntax.

=item B<-repeat>

Set how often the event will be repeated, e.g. 5

=item B<-interval>

Set the time between two following events.
See DATE AND TIME section for its syntax.

=item B<-period>

Set how long an event will last.
See DATE AND TIME section for its syntax.

=item B<-opaque>

Events will be opaque (instead of transparent).

=item B<-todo-start>

First Todo will start as this date.

=item B<-todo-description>

Set the todos' description.

=item B<-todo-summary>

Set the todos' summary.

=item B<-priority>

Set todos' priority. 

=item B<-todoperiod>      todo's period to due

Set todos' due date. Specifiy the difference between start and due date
See DATE AND TIME section for its syntax.

=item B<-complete>

Set todos' complete status. Value between 0 and 100.

=back

=head1 DESCRIPTION

B<create-ics.pl> will create an ics calendar file with events and todos.

=head1 DATE AND TIME

B<create-ics.pl> expects some date and time values as options. The start date must
be of the following format: B<DD.MM.YYYY HH:MM:SS>

And the interval and period options must be a sequence of numbers followed
by a character. The supported characters are:

<I>D for days

<I>M for month

<I>Y for years

<I>h for hours

<I>m for minutes

<I>s for seconds

An interval of two days and 3 three hours would be: 3D4h

=cut

