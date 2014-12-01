#!/bin/bash
#
# Die zugehörige SQL Abfrage:
# select INET_NTOA(ip),spam_hits,ham_hits,lastchange_spam,lastchange_ham
# into outfile '/tmp/test.txt' from sa2dnsbl_new
# where ((IP > INET_ATON('141.58.0.0') and IP < INET_ATON('141.58.255.255'))
# or (IP > INET_ATON('129.69.0.0') and IP < INET_ATON('129.69.255.255')))
# and spam_hits > "2" order by spam_hits;


TMPFILE="$(mktemp)"
HOST="vdb1"
DB="sa2dnsbl2"
TABLE="sa2dnsbl"
USER="sa2dnsbl"
PASSWD="secret"

# line counter
declare -i LINES=0

mysql -h${HOST} -u${USER} -p${PASSWD} $DB > $TMPFILE << EOF
select INET_NTOA(ip),spam_hits,ham_hits,lastchange,reputation \
from $TABLE \
where ((IP > INET_ATON('141.58.0.0') and IP < INET_ATON('141.58.255.255')) \
or (IP > INET_ATON('129.69.0.0') and IP < INET_ATON('129.69.255.255'))) \
and spam_hits > "2" order by spam_hits;
EOF

if test -r $TMPFILE ; then

  while read ip hamhits spamhits date time reputation rest ; do 
     if [ -n "$ip" ]; then
        if [ $LINES = 0 ]; then
           printf "%-15s  spamh  hamh   %-19s  reput  hostname\n" 'IP' 'last change'
           LINES=$LINES+1
        else
           hostname=$(dig +short -x $ip | grep -v 'timed out' | tr '\012' ' ')
           printf "%-15s  %5d  %5d  %10s %8s  %5d  %s\n" \
                  $ip $hamhits $spamhits $date $time $reputation "$hostname"
           LINES=$LINES+1
        fi
     fi
  done < $TMPFILE 

else
  echo "Konnte Eingabedatei $TMPFILE nicht lesen."
fi
rm $TMPFILE
