#!/bin/bash
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
# Copyright (c) 2008-2015 Stefan Jakobs
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

# not public available lists:
# http://www.sbg-rbl.org
# http://dnsbl.invaluement.com

# deprecated blacklists
# relays.ordb.org       # not maintained any more; all positive
# cbl.abuseat.org       # is contained in zen.spamhaus.org
# *.dsbl.org            # not maintained any more
# dynablock.njabl.org   # not maintained and is down
# combined.njabl.org    # not maintained and is down
# combined-hib.dnsiplists.completewhois.com     # dead; all positive
# dnsbl.ahbl.org        # not maintained any more; all positive
# rhsbl.ahbl.org        # not maintained any more; all positive
# intercept.datapacket.net # not maintained any more; all positive
# ircbl.ahbl.org        # not maintained any more; all positive
# tor.ahbl.org          # not maintained any more; all positive

# info
# combined.njabl.org == dnsbl.njabl.org
# zen.spamhaus.org == [pbl+sbl+xbl].spamhaus.org
# ctyme.ixhash.net == ixhash.junkemailfilter.com

# Non RFC 5782 conform lists (127.0.0.2 is not listed):
# dnsrbl.swinog.ch 
# rbl.orbitrbl.com
# rbl.softworking.com
# ubl.unsubscore.com
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

# disabled due to timeouts
# bl.tiopan.com

DNSBLlist=`grep -v ^# <<!
combined.abuse.ch 
dnsrbl.swinog.ch  
bogons.cymru.com
bl.deadbeef.com           
blackholes.five-ten-sg.com
ixhash.junkemailfilter.com
rbl.orbitrbl.com
rbl.softworking.com       
dyna.spamrats.com
noptr.spamrats.com
spam.spamrats.com
psbl.surriel.com          
ubl.unsubscore.com
dialups.visi.com          
bl.blocklist.de
dnsbl.inps.de             
relays.bl.kundenserver.de     
no-more-funn.moensted.dk  
dev.null.dk               
bl.technovision.dk        
st.technovision.dk        
spamsources.fabel.dk      
db.wpbl.info
all.rbl.jp                    
dyndns.rbl.jp                 
rbl.atlbl.net
hbl.atlbl.net
dnsbl.cyberlogic.net
spamtrap.drbl.drand.net
truncate.gbudb.net
blackholes.intersil.net
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
bb.barracudacentral.org
mail-abuse.blacklist.jippg.org
dnsbl.dronebl.org
any.dnsl.ipquery.org
blackholes.mail-abuse.org
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
rep.mailspike.net
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

## variables
#declare -A results_black
#declare -A results_white
#declare -A results_color
declare -i short=0
declare -i warnings=0
declare -i debug=0
declare -i blacklist=0
declare -i whitelist=0
declare -i colorlist=0

## functions

usage()
{
   echo "Usage: $0 -i <ip addr> [-H| [-B] [-C] [-W]]|-p [-d] [-w]"
   echo " -i <ip addr>   query this ip address"
   echo " -H             query all list"
   echo " -B             query only black lists"
   echo " -C             query only colored lists"
   echo " -W             query only white lists"
   echo " -d             enable debug output"
   echo " -p             print list of DNSBLs"
   echo " -s             print a short result"
   echo " -w             print warnings"
   exit 3
}

# reverse IP address bytes
# usage: conver_IP ip_addr
convertIP()
{
   set $(IFS=".";echo $1)
   echo $4.$3.$2.$1
}

# usage: query listtype dnsbl_host rev_ip_addr
query() {
   if [ -z "$3" ]; then
      echo "error (query): not enough parameters"
      return 1
   fi
   local result="$(dig +short ${3}.${2} | tr '\n' ' ')"
   if [ "$warnings" -eq 1 ]; then
      if [[ "$result" =~ connection\ timed\ out ]]; then
         echo "Connection timed out: $i"
      fi
   fi

   if [ -n "$result" ]; then
      if [ "$1" == 'black' ]; then
         #results_black["$2"]="$result"
         echo "$2 $result" >> $file_black
      elif [ "$1" == 'white' ]; then
         #results_white["$2"]="$result"
         echo "$2 $result" >> $file_white
      elif [ "$1" == 'color' ]; then
         #results_color["$2"]="$result"
         echo "$2 $result" >> $file_color
      fi
   fi
   if [ "$debug" -eq 1 ]; then
      echo "debug: query: ${3}.${2} -> $result"
   fi
}

print_lists() {
   echo Blacklists:
   for i in $DNSBLlist ; do
      echo "  $i"
   done
   echo
   echo Colorlists:
   for i in $DNSColorList ; do
      echo "  $i"
   done
   echo
   echo Whitelists:
   for i in $DNSWLlist ; do
       echo "  $i"
   done
   exit
}

# usage: print_warn list_name
print_warn() {
   echo "*** DNSBL WARNING ***"
   echo "Service: $0"
   echo "Host: $HOSTNAME"
   echo "Additional Info: DNSBL-Alarm: $ip is $2 listed on $1"
   echo
}

while getopts ':BCHWi:dpsw' opt; do
  case $opt in
    B)
      blacklist=1
      ;;
    C)
      colorlist=1
      ;;
    H)
      blacklist=1
      colorlist=1
      whitelist=1
      ;;
    W)
      whitelist=1
      ;;
    i)
      ip=$OPTARG
      ;;
    d)
      debug=1
      ;;
    p)
      print_lists
      ;;
    s)
      short=1
      ;;
    w)
      warnings=1
      ;;
    *)
      usage
      ;;
  esac
done

# check options
if [ -z "$ip" ]; then
   echo "error: no ip address given"
   usage
fi
ip_arpa=$(convertIP $ip)

## create temp files
file_black="$(mktemp)"
file_white="$(mktemp)"
file_color="$(mktemp)"

if [ "$debug" -eq 1 ]; then
   echo "tmp file blacklist: $file_black"
   echo "tmp file whitelist: $file_white"
   echo "tmp file colorlist: $file_color"
fi

# query lists and populate results hashes
if [ "$colorlist" -eq 1 ]; then
   for l in $DNSColorList; do
      query 'color' $l $ip_arpa &
   done
fi

if [ "$blacklist" -eq 1 ]; then
  for l in $DNSBLlist; do
      query 'black' $l $ip_arpa &
  done
fi
if [ "$whitelist" -eq 1 ]; then
  for l in $DNSWLlist; do
      query 'white' $l $ip_arpa &
  done
fi
wait


## process results
while read l r; do
    if [[ "$r" =~ 127\.0\.0\.1 ]]; then
       white="$white $l"
    elif [[ "$r" =~ 127\.0\.0\.2 ]]; then
       black="$black $l"
    elif [[ "$r" =~ 127\.0\.0\.3 ]]; then
       yellow="$yellow $l"
    elif [[ "$r" =~ 127\.0\.0\.4 ]]; then
       brown="$brown $l"
    elif [[ "$r" =~ 127\.0\.0\.4 ]]; then
       nobl="$l $nobl"
    else
       other="$l $other"
    fi
done < $file_color
while read l r; do
    if [ -z "$r" ]; then
       true #ignore
    elif [[ "$r" =~ ^127\.0\.0\. ]]; then
       black="$l $black"
    else
       other="$l $other"
    fi
done < $file_black
while read l r ; do
    if [ -z "$r" ]; then
       true # ignore
    elif [[ "$r" =~ ^127\.0\.[0-9]+\. ]]; then
       white="$l $white"
    else
       other="$l $other"
    fi
done < $file_white
#for l in ${!results_color[@]}; do
#    if [ -z "${results_color[$l]}" ]; then
#       true #ignore
#    elif [[ "${results_color[$l]}" =~ 127\.0\.0\.1 ]]; then
#       white="$white $l"
#    elif [[ "${results_color[$l]}" =~ 127\.0\.0\.2 ]]; then
#       black="$black $l"
#    elif [[ "${results_color[$l]}" =~ 127\.0\.0\.3 ]]; then
#       yellow="$yellow $l"
#    elif [[ "${results_color[$l]}" =~ 127\.0\.0\.4 ]]; then
#       brown="$brown $l"
#    elif [[ "${results_color[$l]}" =~ 127\.0\.0\.4 ]]; then
#       nobl="$l $nobl"
#    else
#       other="$l $other"
#    fi
#done
#for l in ${!results_black[@]}; do
#    if [ -z "${results_black[$l]}" ]; then
#       true #ignore
#    elif [[ "${results_black[$l]}" =~ ^127\.0\.0\. ]]; then
#       black="$l $black"
#    else
#       other="$l $other"
#    fi
#done
#for l in ${!results_white[@]}; do
#    if [ -z "${results_white[$l]}" ]; then
#       true # ignore
#    elif [[ "${results_white[$l]}" =~ ^127\.0\.[0-9]+\. ]]; then
#       white="$l $white"
#    else
#       other="$l $other"
#    fi
#done

## generate output
if [ "$short" -eq 1 ]; then
   if [ "$blacklist" -eq 1 ]; then
      echo "$black"
   fi
   if [ "$whitelist" -eq 1 ]; then
      echo "$white"
   fi
   if [ "$colorlist" -eq 1 ]; then
      echo "yellow: $yellow ;brown: $brown ;nobl: $nobl"
   fi
elif [ "$short" -eq 0 ]; then
   if [ "$blacklist" -eq 1 ]; then
      for l in $black; do
         print_warn $l BLACK
      done
   fi
   if [ "$whitelist" -eq 1 ]; then
      for l in $white; do
         print_warn $l WHITE
       done
   fi
   if [ "$colorlist" -eq 1 ]; then
      for l in $yellow; do
         print_warn $l YELLOW
      done
      for l in $brown; do
         print_warn $l BROWN
      done
      for l in $nobl; do
         print_warn $l NOBL
      done
      for l in $other; do
         print_warn $l OTHER
      done
   fi
else
   echo "error: short option $short not supported"
   exit 1
fi

echo "Black:"
cat $file_black
echo "white:"
cat $file_white
echo "color:"
cat $file_color
rm "$file_black" "$file_white" "$file_color"
