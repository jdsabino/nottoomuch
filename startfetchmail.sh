#!/bin/sh
# -*- mode: shell-script; sh-basic-offset: 8; tab-width: 8 -*-
# $ startfetchmail.sh $
#
# Created: Wed 06 Mar 2013 17:17:58 EET too
# Last modified: Fri 07 Feb 2014 23:20:27 +0200 too

# Fetchmail does not offer an option to daemonize it after first authentication
# is successful (and report if it failed). After 2 fragile attempts to capture
# the password in one-shot fetch (using tty play) and if that successful
# run fetchmail in daemon mode I've settled to run this script and just check
# from log whether authentication succeeded...

set -eu
#set -x

case $# in 5) ;; *) exec >&2
	echo
	echo Usage: $0 '(143|993) (keep|nokeep)' user server mda_cmdline
	echo
	echo This script runs fetchmail with options to use encrypted IMAP
	echo connection when fetching email. STARTTLS is required when using
	echo port 143. IMAP IDLE feature used when applicable.
	echo
	echo fetchmail is run in background '(daemon mode)' and first 2 seconds
	echo of logs is printed to terminal so that user can determine whether
	echo authentication succeeded.
	echo
	echo Example:
	echo
	echo '' $0 143 keep $USER mailhost.example.org "'/usr/bin/procmail -d %T'"
	echo
	echo The above example delivers mail from imap server to user mbox
	echo 'in spool directory (usually /var[/spool]/mail/$USER, or $MAIL).'
	echo 'The mails are not removed from imap server'
	echo
	exit 1
esac

case $1 in 143) ssl='--sslproto TLS1' ;; *) ssl=--ssl ;; *) exec >&2
	echo
	echo "$0: '$2' is not either '143' or '993'".
	echo
esac

case $2 in keep) keep=keep ;; nokeep) keep= ;; *) exec >&2
	echo
	echo "$0: '$2' is not either 'keep' or 'nokeep'".
	echo
	exit 1
esac
shift 2

imap_user=$1 imap_server=$2 mda_cmdline=$3
shift 3
readonly ssl keep imap_server imap_user mda_cmdline

cd "$HOME"

mda_cmd=`expr "$mda_cmdline" : ' *\([^ ]*\)'`
test -s $mda_cmd || {
	exec >&2
	case $mda_cmd in
	  /*)	echo "Cannot find command '$mda_cmd'" ;;
	  *)	echo "Cannot find command '$HOME/$mda_cmd'"
	esac
	exit 1
}

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

poll '"$imap_server"' proto IMAP user "'"$imap_user"'" '"$ssl"' '$keep' idle
  mda "'"$mda_cmdline"'"
' > fmconf
chmod 700 fmconf

( set -x; exec fetchmail -f fmconf -v )

#x fetchmail -f /dev/null -k -v -p IMAP --ssl --idle -d 60 --logfile $logfile\
#	-u USER --mda '/usr/bin/procmail -d %T' SERVER

sleep 2
test -s $logfile || sleep 2
rm -f fmconf
kill $logfilepid
trap - 0
echo
ps x | grep '\<fetch[m]ail\>'
echo
echo "Above the end of current fetchmail log '$HOME/$logfile'"
echo "is shown. Check there that your startup was successful."
echo
