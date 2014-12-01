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

# This script reads a transport table and will test each server if
# it supports recipient verification (reject unknown user).

##### Variables: #####
# ignore lines in transport table which match the following regex
IGNORE="error:|retry:|local:|ipv4-only"
# check this subdomain if there is a catch all in the transport table
SUBDOMAIN="www"
# DNS MX lookups are disabled for entries that match:
NONMX="nonmx-smtp"
# the script which will connect to the server and test the rcpt to:
CHECK_RCPT_SCRIPT="check-rcpt.pl"
# the user part of the email address
TESTUSER="foobar$(mktemp -t -u | cut -d. -f2)"
# ignore MX records which match the following regex
MAILRELAY="mx.example.com"

# Enable debug output (don't change it here)
# DEBUG will be set by the second argument to this script
# ''
# 0 ... disable parallel requests
# 1 ... disable parallel requests, print additional info
# 2 ... disable parallel requests, print additional info, set -x
DEBUG=''

##### Functions: #####
usage() {
   echo "$0 <transport table> [<debug level>]"
   exit 1
}

# call_check_rcpt <to> <nexthop> <domain>
# run $CHECK_RCPT_SCRIPT and print the result/message
call_check_rcpt() {
   local to=$1
   local nexthop=$2
   local domain=$3
   local result=""

   if [ -z "$nexthop" ] || [ -z "$to" ]; then
      echo "error: nexthop or to is empty!"
      exit 1;
   fi
   result=$($CHECK_RCPT_SCRIPT -d -to $to $nexthop 2>&1)
   if [ $? -eq 0 ]; then
      if [ -n "$(grep "^rcpt to   : OK " <<< "$result")" ]; then
         # print message that recipient verfication doesn't exists
         #echo "$result" | grep "GLOB" | cut -d")" -f2-
         #echo "FAIL: recipient verification failed! ($domain)"
         result="$(grep "GLOB" <<< "$result" | cut -d")" -f2-)"
         print_report "$domain" "$nexthop" "$result"
      else
         if (( $DEBUG )); then echo "OK: recipient verified! ($domain)"; fi
      fi
   else
      echo "warning: calling '$CHECK_RCPT_SCRIPT -d -to $to $nexthop' failed!"
   fi
}

# eval_dns <to> <nexthop> <domain>
# parse nexthop and check MX records if necessary.
# run function call_check_rcpt() for each identified server
eval_dns() {
   local to=$1
   local nexthop=$2
   local domain=$3

   if [ -z "$to" ]; then
      echo "error: to is empty!"
      exit 1;
   fi
   if [ "$DEBUG" = 1 ]; then echo "eval: to = $to"; fi
   if [ -n "$(egrep "^\[.*\]$" <<< $nexthop)" ]; then
      nexthop=$(tr -d '[]' <<< $nexthop)
      if [ "$DEBUG" = '1' ]; then
         echo "eval: nexthop = $nexthop"
         call_check_rcpt "$to" "$nexthop" "$domain"
      else
         call_check_rcpt "$to" "$nexthop" "$domain" &
      fi 
   else
      local LIST_OF_MX=$(dig +short -t mx $nexthop | grep -v "$MAILRELAY" | cut -d' ' -f2)
      while read mx ; do
         if [ "$DEBUG" = '1' ]; then
            echo "eval: mx = $mx"
            call_check_rcpt "$to" "$mx" "$domain"
         else
            call_check_rcpt "$to" "$mx" "$domain" &
         fi
      done <<< "$LIST_OF_MX"
   fi
}

# print_report <domain> <server> <result>
# print a report which can be send via email
print_report() {
   local domain=$1
   local server=$2
   local result=$3

   cat <<- EOT
	------ start to cut here -------------------------------------------

	Dear Mailadmin,

	a routine check has revealed that your server
	"$server" do not perform a proper recipient
	verification. That means it accepts all email for the domain 
	"$domain":


	Recipient-Test
	==============

	Connecting to  $server ...
	$result

	Please enable the recipient verification again.

	------ end to cut here ---------------------------------------------

EOT
}

##### Main: #####

# Check if there is one argument
if [ -z $1 ]; then
   usage
else
   if ! ( test -r $1 ); then
      echo "Error: can not read transport table ($1)"
      exit 1
   else
      TRANSPORT_TABLE="$1"
   fi
   if   [ "$2" = '1' ]; then DEBUG=1;
   elif [ "$2" = '2' ]; then
      DEBUG=1;
      set -x;
   fi
fi

# check if dig is installed
if which dig &> /dev/null; then
   DIG=$(which dig)
else
   echo "error: dig not found!"
   exit 1
fi

# check if $CHECK_RCPT_SCRIPT exists and is executable
if which $CHECK_RCPT_SCRIPT &> /dev/null ; then
   CHECK_RCPT_SCRIPT=$(which $CHECK_RCPT_SCRIPT)
else
   echo "error: $CHECK_RCPT_SCRIPT not found!"
   exit 1
fi

# read transport table and remove all empty entries, entries with @ in
# the next hop or ignored lines
TRANSPORTS=$(egrep -v "^#|^\s*$|${IGNORE}" $TRANSPORT_TABLE | expand | tr -s ' ')

# vorgehen:
# * $domain beginnt nicht mit einem Punkt (.):
#   * $proto == ":" und $nexthop ist NICHT leer:
#     * $nexthop ist eingeklammert ([...]):
#       - Verbinde dich zu $nexthop und
#       - und teste auserfoobar@$domain
#     * $nexthop ist nicht eingeklammert:
#       - Ermittle den MX-record von $nexthop und verbinde dich
#       - und teste auserfoobar@$domain
#   * $proto == ":" und $nexthop ist leer:
#     - Verbinde dich mit allen MX-records (außer mailrelay)
#     - und test auf auserfoobar@$domain
#   * $proto == "nonmx-smtp:" und $nexthop ist NICHT leer (macht keinen Sinn)
#     * $nexthop ist eingeklammert ([...]):
#       - Verbinde dich zu $nexthop und
#       - und teste auserfoobar@$domain
#     * $nexthop ist nicht eingeklammert:
#       - Ermittle den MX-record von $nexthop und verbinde dich
#       - und teste auserfoobar@$domain
#   * $proto == "nonmx-smtp:" und $nexthop ist leer
#     - Verbinde dich zu A-record von $domain
#     - und teste auserfoobar@$domain
# * $domain beginnt mit einem Punkt (.):
#   * $proto == ":" und $nexthop ist NICHT leer:
#     * $nexthop ist eingeklammert ([...]):
#       - Verbinde dich zu $nexthop und
#       - und teste auserfoobar@$www.$domain
#     * $nexthop ist nicht eingeklammert:
#       - Ermittle den MX-record von $nexthop und verbinde dich
#       - und teste auserfoobar@www.$domain
#   * $proto == ":" und $nexthop ist leer:
#     - Verbinde dich mit allen MX-records (außer mailrelay)
#     - und test auf auserfoobar@$www.domain
#   * $proto == "nonmx-smtp:" und $nexthop ist NICHT leer (macht keinen Sinn)
#     * $nexthop ist eingeklammert ([...]):
#       - Verbinde dich zu $nexthop und
#       - und teste auserfoobar@$www.$domain
#     * $nexthop ist nicht eingeklammert:
#       - Ermittle den MX-record von $nexthop und verbinde dich
#       - und teste auserfoobar@www.$domain
#   * $proto == "nonmx-smtp:" und $nexthop ist leer
#     - Verbinde dich zu A-record von $domain
#     - und teste auserfoobar@$www.domain

while read domain action rest; do
   # $domain must not be empty
   if [ -z "$domain" ]; then
      echo "error: there's no domain!!!"
      exit 1
   fi
   # check if $proto has a colon
   if [ -n "$(grep ":" <<< $action)" ]; then
      proto="$(cut -d: -f1 <<< $action)"
      nexthop="$(cut -d: -f2 <<< $action)"
   else
      echo "error: Protocol syntax error!"
      exit 1
   fi
   if [ "$DEBUG" = 1 ]; then
      echo "domain:  $domain"
      echo "nexthop: $nexthop"
      echo "proto:   $proto"
      if [ -n "$rest" ]; then
         echo "rest:    $rest"
      fi
   fi
   if [ -n "$(grep "^\." <<< $domain)" ]; then # subdomains
      if [ -z "$proto" ]; then 
         if [ -n "$nexthop" ]; then 
            eval_dns "${TESTUSER}@${SUBDOMAIN}${domain}" "${nexthop}" "*$domain"
         else
            eval_dns "${TESTUSER}@${SUBDOMAIN}${domain}" "${SUBDOMAIN}${domain}" "*$domain"
         fi
      else
         if [ "$proto" = "$NONMX" ]; then
            if [ -n "$nexthop" ]; then
               # this combination doesn't make sense
               echo "Warning: useless combination: $domain $proto $nexthop"
               eval_dns "${TESTUSER}@${SUBDOMAIN}${domain}" "$nexthop" "*$domain"
            else
               # nexthop is a-record of SUBDOMAIN.domain, so add brackets
               eval_dns "${TESTUSER}@${SUBDOMAIN}${domain}" "[${SUBDOMAIN}${domain}]" "*$domain"
            fi
         else
            echo "error: unknown protocol: $proto"
            exit 1
         fi
      fi
   else # main domain
      if [ -z "$proto" ]; then
         if [ -n "$nexthop" ]; then
            eval_dns "${TESTUSER}@${domain}" "$nexthop" "$domain"
         else
            eval_dns "${TESTUSER}@${domain}" "$domain" "$domain"
         fi
      else
         if [ "$proto" = "$NONMX" ]; then
            if [ -n "$nexthop" ]; then
               # this combination doesn't make sense
               echo "Warning: useless combination: $domain $proto $nexthop"
               eval_dns "${TESTUSER}@${domain}" "$nexthop" "$domain"
            else
               # nexthop is a-record of domain, so add brackets
               eval_dns "${TESTUSER}@${domain}" "[${domain}]" "$domain"
            fi
         else
            echo "error: unknown protocol: $proto"
            exit 1
         fi
      fi
   fi 
done <<< "$TRANSPORTS"
wait
