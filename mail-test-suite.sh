#!/bin/bash

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


#### VARIABLES ####

declare -A good_rcpts
declare -A bad_rcpts
declare -A bad_senders
declare -A good_senders

CONFIG='./mail-test-suite.cf'
ENVIRONMENT='testing'
CHECK_RCPT='/usr/local/bin/check-rcpt.pl'
SMTP_SERVER='localhost'
DEBUG='0'
WAIT_SECS='2'
debug_opt[0]=''
debug_opt[1]=''
debug_opt[2]='-d'

#### FUNCTIONS ####

function usage {
   echo "$0 [-d ] [-e <environment>] [-c <config file>]"
   echo "     [-b <path/to/check-rcpt.pl>] [-s <SMTP server>]"
   echo "     [-w <seconds>]"
   exit 0
}

#### PREPARE ####

while getopts ":b:c:e:s:w:D" opt; do
  case $opt in
    b)
      CHECK_RCPT="$OPTARG" ;;
    c)
      CONFIG="$OPTARG" ;;
    e)
      ENVIRONMENT="$OPTARG" ;;
    s)
      SMTP_SERVER="$OPTARG" ;;
    w)
      WAIT_SECS="$OPTARG" ;;
    D)
      DEBUG=$(( $DEBUG + 1 )) ;;
    *)
      usage ;;
  esac
done

if ! [ -x "$CHECK_RCPT" ]; then
   echo "error: can not execute check-rcpt.pl ($CONFIG)"
   exit 1
fi
if [ -z "$SMTP_SERVER" ]; then
   echo "error: no SMTP server named!"
   exit 1
fi
if ! [[ "$WAIT_SECS" =~ ^[0-9]+$ ]]; then
   echo "error: time between server connects must be a number (seconds)!"
   exit 1
fi

if ! [ -r "$CONFIG" ]; then
   echo "error: can not read $CONFIG"
   exit 1
fi
source "$CONFIG"

# check if we have data
if [[ "${#good_rcpts[@]}" -le 0 ]] && [[ "${#bad_rcpts[@]}" -le 0 ]] ; then
   echo "error: there is no data in 'bad_rcpts' and/or 'good_rcpts'!"
   exit 1
fi

if [[ "${#good_senders[@]}" -le 0 ]] ; then
   good_senders["$ENVIRONMENT"]='auser@example.com'
fi


#### MAIN ####

for sender in ${bad_senders["$ENVIRONMENT"]} ; do
   [ "$DEBUG" -gt 0 ] && echo "check bad sender: $sender"
   for rcpt in ${good_rcpts["$ENVIRONMENT"]} ; do
      [ "$DEBUG" -gt 0 ] && echo "    check good rept: $rcpt"
      [ "$DEBUG" -gt 1 ] && echo $CHECK_RCPT ${debug_opt[$DEBUG]} -quiet -expect-reject -from "$sender" -to "$rcpt" "$SMTP_SERVER"
      if ! $CHECK_RCPT ${debug_opt[$DEBUG]} -quiet -expect-reject -from "$sender" -to "$rcpt" "$SMTP_SERVER" ; then
         echo "fail: $sender -> $rcpt"
      fi
      sleep $WAIT_SECS
   done
   
   for rcpt in ${bad_rcpts["$ENVIRONMENT"]} ; do
      [ "$DEBUG" -gt 0 ] && echo "    check bad rcpt: $rcpt"
      [ "$DEBUG" -gt 1 ] && echo $CHECK_RCPT ${debug_opt[$DEBUG]} -quiet -expect-reject -from "$sender" -to "$rcpt" "$SMTP_SERVER"
      if ! $CHECK_RCPT ${debug_opt[$DEBUG]} -quiet -expect-reject -from "$sender" -to "$rcpt" "$SMTP_SERVER" ; then
         echo "fail: $sender -> $rcpt"
      fi
      sleep $WAIT_SECS
   done
done

for sender in ${good_senders["$ENVIRONMENT"]} ; do
   [ "$DEBUG" -gt 0 ] && echo "check good sender: $sender"
   for rcpt in ${good_rcpts["$ENVIRONMENT"]} ; do
      [ "$DEBUG" -gt 0 ] && echo "    check good rcpt: $rcpt"
      [ "$DEBUG" -gt 1 ] && echo $CHECK_RCPT ${debug_opt[$DEBUG]} -quiet -from "$sender" -to "$rcpt" "$SMTP_SERVER"
      if ! $CHECK_RCPT ${debug_opt[$DEBUG]} -quiet -from "$sender" -to "$rcpt" "$SMTP_SERVER" ; then
         echo "fail: $sender -> $rcpt"
      fi
      sleep $WAIT_SECS
   done
   
   for rcpt in ${bad_rcpts["$ENVIRONMENT"]} ; do
      [ "$DEBUG" -gt 0 ] && echo "    check bad rcpt: $rcpt"
      [ "$DEBUG" -gt 1 ] && echo $CHECK_RCPT ${debug_opt[$DEBUG]} -quiet -expect-reject -from "$sender" -to "$rcpt" "$SMTP_SERVER"
      if ! $CHECK_RCPT ${debug_opt[$DEBUG]} -quiet -expect-reject -from "$sender" -to "$rcpt" "$SMTP_SERVER" ; then
         echo "fail: $sender -> $rcpt"
      fi
      sleep $WAIT_SECS
   done
done


### TODO:
sample_spam_GTUBE_nojunk=$(cat << EOT
Subject: Test spam mail (GTUBE)
Message-ID: <GTUBE1.1010101@example.net>
Date: Wed, 23 Jul 2003 23:30:00 +0200
From: Sender <sender@example.net>
To: Recipient <recipient@example.net>
Precedence: junk
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit

This is the GTUBE, the
        Generic
        Test for
        Unsolicited
        Bulk
        Email

If your spam filter supports it, the GTUBE provides a test by which you
can verify that the filter is installed correctly and is detecting incoming
spam. You can send yourself a test mail containing the following string of
characters (in upper case and with no white spaces and line breaks):

XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X

You should send this test mail from an account outside of your network.
EOT
)
# echo "$sample_spam_GTUBE_nojunk" | sendmail -i $rcpt
# /usr/lib/nagios/plugins/check_imap_receive -m 'Junk E-Mail' -U st000001 -P geheim -H imap.example.com -s SUBJECT -s 'Test spam mail (GTUBE)' --ssl
