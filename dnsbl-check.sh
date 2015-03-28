#!/bin/sh
# 
# dnsbl-check.sh
#####################################################################
# Original by Damon Tajeddini (dta) 10.03.2009
# Modified and  maintained by:
#    Stefan Jakobs <logwatch at localside.net>
#
# Please send all comments, suggestions, bug reports,
#    etc, to logwatch at localside.net.
#####################################################################
# Copyright (c) 2008-2014 Stefan Jakobs
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
#
MAIL_RCPT="postmaster@localhost"

# not public available lists:
# http://www.sbg-rbl.org
# http://dnsbl.invaluement.com

# deprecated blacklists
# relays.ordb.org       # not maintained any more; all positive
# cbl.abuseat.org       # is contained in zen.spamhaus.org
# *.dsbl.org            # not maintained any more
# dynablock.njabl.org   # not maintained and will be shutdown soon
# combined-hib.dnsiplists.completewhois.com     # dead; all positive
# *.ahbl.org (dnsbl, rhsbl, ircbl, tor) # not maintained any more;

# info
# combined.njabl.org == dnsbl.njabl.org
# zen.spamhaus.org == [pbl+sbl+xbl].spamhaus.org
# ctyme.ixhash.net == ixhash.junkemailfilter.com

# Non RFC 5782 conform lists (127.0.0.2 is not listed):
# dnsrbl.swinog.ch 
# rbl.orbitrbl.com
# rbl.softworking.com
# dyndns.rbl.jp
# hbl.atlbl.net
# dnsbl.cyberlogic.net
# intercept.datapacket.net
# spamtrap.drbl.drand.net
# blackholes.intersil.net
# bl.mailspike.net
# combined.rbl.msrbl.net
# badnets.spameatingmonkey.net
# ixhash.spameatingmonkey.net
# rhsbl.ahbl.org
# tor.ahbl.org
# mail-abuse.blacklist.jippg.org
# any.dnsl.ipquery.org
# blackholes.mail-abuse.org
# dsn.rfc-ignorant.org
# fulldom.rfc-ignorant.org

DNSBLlist=`grep -v ^# <<!
combined.abuse.ch 
dnsrbl.swinog.ch  
bogons.cymru.com
bl.deadbeef.com           
blackholes.five-ten-sg.com
cidr.bl.mcafee.com
rbl.orbitrbl.com
rbl.softworking.com       
dyna.spamrats.com
noptr.spamrats.com
spam.spamrats.com
psbl.surriel.com          
#bl.tiopan.com
dialups.visi.com          
bl.blocklist.de
dnsbl.inps.de             
relays.bl.kundenserver.de     
no-more-funn.moensted.dk  
dev.null.dk               
#bl.technovision.dk        
st.technovision.dk        
spamsources.fabel.dk      
db.wpbl.info
all.rbl.jp                    
dyndns.rbl.jp                 
#rbl.atlbl.net
#hbl.atlbl.net
dnsbl.cyberlogic.net
intercept.datapacket.net
spamtrap.drbl.drand.net
truncate.gbudb.net
blackholes.intersil.net
ixhash.junkemailfilter.com
generic.ixhash.net
hosteurope.ixhash.net
dnsbl.kempt.net
bl.mailspike.net
ix.dnsbl.manitu.net
combined.rbl.msrbl.net
korea.services.net
dnsbl.sorbs.net
spam.dnsbl.sorbs.net
bl.spamcop.net
backscatter.spameatingmonkey.net
badnets.spameatingmonkey.net
bl.spameatingmonkey.net
ixhash.spameatingmonkey.net
netbl.spameatingmonkey.net
dnsbl-1.uceprotect.net
dnsbl-2.uceprotect.net
dnsbl-3.uceprotect.net
virbl.dnsbl.bit.nl
l2.apews.org
ips.backscatterer.org
mail-abuse.blacklist.jippg.org
dnsbl.dronebl.org
#any.dnsl.ipquery.org
blackholes.mail-abuse.org
combined.njabl.org
dnsbl.proxybl.org
access.redhawk.org
dsn.rfc-ignorant.org
fulldom.rfc-ignorant.org
bl.spamcannibal.org
zen.spamhaus.org
dul.ru
!`

DNSColorList=`grep -v ^# <<!
hostkarma.junkemailfilter.com
list.quorum.to
!`

DNSWLlist=`grep -v ^# <<!
sa-accredit.habeas.com    
iadb.isipp.com
wl.mailspike.net
whitebl.spameatingmonkey.net
list.dnswl.org
resl.emailreg.org
!`


# reverse IP address bytes
convertIP()
{
   set `IFS=".";echo $1`
   echo $4.$3.$2.$1
}

usage()
{
   echo "Usage: $0 [-H <host>|-W <host>|-p]"
   echo " -H IP address to check for blacklisting"
   echo " -W IP address to check for whitelisting"
   echo " -p Print list of DNSBLs"
   exit 3
}

# Checks the IP with list of DNSBL servers
check()
{
   for i in $DNSBLlist; do
      RESULT=$(dig $ip_arpa.$i +short)
      if grep -q "^127.0.0." <<< "$RESULT"; then
         #mail -s "** Service Alert: $ip found on $i **" $MAIL_RCPT <<!
         cat <<!
 *** DNSBL WARNING ***
 Service: $progname
 Host: `hostname`
 Date/Time: `date`
 Additional Info: DNSBL-Alarm: $ip is listed on $i
!
      elif grep -q "connection timed out" <<< "$RESULT"; then
         echo "Connection timed out: $i"
      fi
  done
} # check

# Checks the IP with list of DNSWL servers
check_white()
{
   for i in $DNSWLlist ; do
      RESULT=$(dig $ip_arpa.$i +short)
      if egrep -q "^127.0.[0-9]+." <<< "$RESULT" ; then
         #mail -s "** Service Info: $ip found on $i **" $MAIL_RCPT <<!
         cat <<!
 *** DNSWL INFORMATION ***
 Service: $progname
 Host: `hostname`
 Date/Time: `date`
 Additional Info: DNSWL-Info: $ip is listed on $i
!
      elif grep "connection timed out" <<< "$RESULT"; then
         echo "Connection timed out: $i"
      fi
   done
} # check


# Check the IP with colored lists servers
check_colored()
{
   for i in $DNSColorList; do
      RESULT=$(dig $ip_arpa.$i +short)
      if grep -q "connection timed out" <<< "$RESULT"; then
         echo "Connection timed out: $i"
      fi
      if [[ $1 = "black" ]]; then
         case `grep "^127.0.0." <<< "$RESULT"` in
            "127.0.0.1") OUT="Additional Info: DNSBL-listed: $ip is WHITE listed on $i"
                    ;;
            "127.0.0.5") OUT="Additional Info: DNSBL-listed: $ip is NOBL isted on $i"
                    ;;
         esac
      else
         case `grep "^127.0.0." <<< "$RESULT"` in
            "127.0.0.1") OUT="Additional Info: DNSBL-listed: $ip is WHITE listed on $i"
		              ;;
            "127.0.0.2") OUT="Additional Info: DNSBL-Alarm: $ip is BLACK listed on $i"
	                 ;;
            "127.0.0.3") OUT="Additional Info: DNSBL-Alarm: $ip is YELLOW listed on $i"
                    ;;
            "127.0.0.4") OUT="Additional Info: DNSBL-Alarm: $ip is BROWN listed on $i"
                    ;;
            "127.0.0.5") OUT="Additional Info: DNSBL-Alarm: $ip is NOBL isted on $i"
                    ;;
         esac
      fi
      if [[ -n $OUT ]]; then
         #mail -s "** Service Alert: $ip found on $i **" $MAIL_RCPT <<!
         cat <<! 
 *** DNSBL WARNING ***
 Service: $progname
 Host: `hostname`
 Date/Time: `date`
 $OUT
!
      fi
   done
} # check_colored

while [ -n "$1" ]; do
   case $1 in
      -H)
         if [ -z "$2" ]; then
            echo "ip address missing"
            exit
         fi
         ip=$2
         ip_arpa=`convertIP $ip`
         check_colored black
         check ;;

      -W)
         if [ -z "$2" ]; then
            echo "ip address missing"
            exit
         fi
         ip=$2
         ip_arpa=`convertIP $ip`
         check_colored white
         check_white ;;

      -p)
         echo Blacklists:
         for i in $DNSBLlist ; do
            echo "  $i"
         done
         echo Colorlists:
         for i in $DNSColorList ; do
            echo "  $i"
         done
         echo Whitelists:
         for i in $DNSWLlist ; do
            echo "  $i"
         done
         exit;;

      --help)
         usage
         exit;;

      *)
         if [ -z "$1" ]; then
            usage
         fi
         echo "unknown command: $1"
         exit;;
   esac

   shift 2;
done

