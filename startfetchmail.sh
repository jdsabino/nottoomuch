#!/bin/sh
# -*- mode: shell-script; sh-basic-offset: 8; tab-width: 8 -*-
# $ startfetchmail.sh $
#
# Created: Wed 06 Mar 2013 17:17:58 EET too
# Last modified: Mon 06 Jan 2014 12:14:03 +0200 too

# Fetchmail does not offer an option to daemonize it after first authentication
# is successful (and report if it failed). After 2 fragile attempts to capture
# the password in one-shot fetch (using tty play) and if that successful
# run fetchmail in daemon mode I've settled to run this script and just check
# from log whether authentication succeeded...

set -eu
#set -x

case $# in 4) ;; *) exec >&2
	echo
	echo Usage: $0 '(keep|nokeep)' imap_user imap_server mda_cmdline
	echo
	echo This script runs fetchmail with options to use IMAPS IDLE feature
	echo when fetching email '(IMAPS always, IDLE when applicable)'.
	echo
	echo fetchmail is run in background '(daemon mode)' and first 2 seconds
	echo of logs is printed to terminal so that user can determine whether
	echo authentication succeeded.
	echo
	echo Example:
	echo
	echo '  ' $0 keep $USER mailhost.example.org "'/usr/bin/procmail -d %T'"
	echo
	echo The above example delivers mail from imap server to user mbox
	echo 'in spool directory (usually /var[/spool]/mail/$USER, or $MAIL).'
	echo 'The mails are not removed from imap server'
	echo
	exit 1
esac

case $1 in keep) keep=keep ;; nokeep) keep= ;; *) exec >&2
	echo
	echo "$0: '$1' is not either 'keep' or 'nokeep'".
	echo
	exit 1
esac

imap_user=$2 imap_server=$3 mda_cmdline=$4
shift 4
readonly keep imap_server imap_user mda_cmdline

cd "$HOME"

if test -f .fetchmail.pid
then
	read pid < .fetchmail.pid
	if kill -0 "$pid" 2>/dev/null
	then
		echo "There is (fetchmail) process running in pid $pid"
		ps -p "$pid"
		echo "If this is not fetchmail, remove the file"
		exit 1
	fi
fi

logfile=.fetchmail.log
if test -f $logfile
then
	echo "Rotating logfile '$logfile'"
	mv "$logfile".2 "$logfile".3 2>/dev/null || :
	mv "$logfile".1 "$logfile".2 2>/dev/null || :
	mv "$logfile"   "$logfile".1
fi
touch $logfile

tail -f $logfile &
logfilepid=$!

trap 'rm -f fmconf; kill $logfilepid' 0

echo '
set daemon 60
set logfile '$logfile'

poll '"$imap_server"' proto IMAP user "'"$imap_user"'" ssl '$keep' idle
  mda "'"$mda_cmdline"'"
' > fmconf
chmod 700 fmconf

( set -x; exec fetchmail -f fmconf -v )

#x fetchmail -f /dev/null -k -v -p IMAP --ssl --idle -d 60 --logfile $logfile\
#	-u USER --mda '/usr/bin/procmail -d %T' SERVER

sleep 2
test -s $logfile || sleep 2
rm -f $fmconf
kill $logfilepid
trap - 0
echo
ps x | grep '\<fetch[m]ail\>'
echo
echo "Above the end of current fetchmail log '$HOME/$logfile'"
echo "is shown. Check there that your startup was successful."
echo
