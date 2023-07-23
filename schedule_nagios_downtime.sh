#!/bin/bash

# Bash script to schedule downtime for Host

function die {
  echo $1;
  exit 1;
}

if [ $# -lt 1 ]; then
  echo "$0 <host> [<user>]"
  exit 0;
elif [ $# -ge 2 ]; then
  USER=$2
  PASS=$3
fi

HOST=$1
NAGURL=http://10.8.0.1:81/nagios/cgi-bin/cmd.cgi
MINUTES=30

echo Scheduling downtime on nagios for $HOST

export MINUTES

# read password
if [[ ! $PASS ]]; then
read -s  -p "Password for $USER:" PASS
fi
echo ""  # newline after prompt


# The following is urlencoded already
STARTDATE=`date "+%d-%m-%Y+%H%%3A%M%%3A%S"`
# This gives us the date/time X minutes from now
ENDDATE=`date "+%d-%m-%Y+%H%%3A%M%%3A%S" -d "$MINUTES min"`
#echo $STARTDATE $ENDDATE
curl --silent --show-error \
    --data cmd_typ=55 \
    --data cmd_mod=2 \
    --data host=$HOST \
    --data "com_author=$USER" \
    --data "com_data=scheduled+reboot" \
    --data trigger=0 \
    --data "start_time=$STARTDATE" \
    --data "end_time=$ENDDATE" \
    --data fixed=1 \
    --data hours=2 \
    --data minutes=0 \
    --data childoptions=0 \
    --data btnSubmit=Commit \
    $NAGURL -u "$USER:$PASS" | grep -q "Your command request was successfully submitted to Nagios for processing." || die "Failed to contact nagios";
echo Scheduled downtime on nagios
