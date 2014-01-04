#!/bin/sh
# -*- mode: shell-script; sh-basic-offset: 8; tab-width: 8 -*-
# $ startfetchmail.sh $
#
# Created: Wed 06 Mar 2013 17:17:58 EET too
# Last modified: Sat 04 Jan 2014 14:44:29 +0200 too

# Fetchmail does not offer an option to daemonize it after first authentication
# is successful (and report if it failed). After 2 fragile attempts to capture
# the password in one-shot fetch (using tty play) and if that successful
# run fetchmail in daemon mode I've settled to run this script and just check
# from log whether authentication succeeded...

set -eu
#set -x

# Edit the following 2 imap_* variables to contain your values.

imap_server=mail.host.tld
imap_user=username

warn () { echo "$@" >&2; }
die () { echo "$@" >&2; exit 1; }

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

trap 'rm -f fmconf' 0
echo '
set daemon 60
set logfile '$logfile'

poll '"$imap_server"' proto IMAP user "'"$imap_user"'" ssl keep idle
  mda "/usr/bin/procmail -d %T"
' > fmconf
chmod 700 fmconf

( set -x; exec fetchmail -f fmconf -v )

#x fetchmail -f /dev/null -k -v -p IMAP --ssl --idle -d 60 --logfile $logfile\
#	-u USER --mda '/usr/bin/procmail -d %T' SERVER

tail -f $logfile &
sleep 2
kill $!
echo
ps x | grep '\<fetch[m]ail\>'
echo
echo "Above the end of current fetchmail log '$HOME/$logfile'"
echo is shown. Check there that your startup was successful.
