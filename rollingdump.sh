#!/bin/sh

if [ -r /etc/defaults/periodic.conf ]; then
    . /etc/defaults/periodic.conf
    source_periodic_confs
fi

rc=0

# USAGE
#
# variable n controls dry run:
#   env n=echo ./rollingdump.sh 0
#
# NOTICE
#
# On FreeBSD weekly backup is done on Saturday, which is Day 6 of the week.
# The Level 2 backup that follows it would appear out of order in 'ls -l' output,
# because D1 represents Monday and D6 represents Saturday.

NAME=rollingdump
LEVEL=${1:-0}
MARKER=$2

if [ $# -eq 2 ]; then
    echo Too fiew arguments to run backup
    return
fi

if [ $# -gt 2 -a _$MARKER = _'BACKUP' ]; then
    # Primary backup of one item from /usr/local/etc/rollingdumptab
    name=$3
    fspath=$4
    echo Processing ${fspath} as ${name}

    weekFreq=6
    # Example of zero pad number:   monthMod=$(printf %02d $monthMod)
	# dayOfWeek values: 1-6, where 1 is Monday
    dayOfWeek=`date -j +"%u"`
    # %W is ISO week of year
    weekOfYear=`date -j +"%W"`
    weekMod=`expr ${weekOfYear} % ${weekFreq}`

    dumpargs="-C16 -b128 -uaL -h1"
    dump="/sbin/dump -${LEVEL} ${dumpargs}"
    bzip2args=--best
    compress="/usr/bin/bzip2 ${bzip2args}"
    backupDir=/var/backups/roll
    case $LEVEL in
	0)
	    # full backup
	    suffix="W${weekMod}-L${LEVEL}"

	    ;;
	*)
	    # not a full backup
	    suffix="W${weekMod}-L${LEVEL}-D${dayOfWeek}"
	    ;;
    esac
    dumpFileName=${name}_${suffix}.dump
    echo Removing old backup files
    ${n} rm -v ${backupDir}/${name}_${suffix}*.dump*
    echo Dumping to ${dumpFileName}
    ${n} ${dump} -f ${backupDir}/${dumpFileName} ${fspath}
    ${n} ${compress} ${backupDir}/${dumpFileName}
    return
fi

case "${rollingdump_enable:-YES}" in
    [Nn][Oo])
    ;;
    *)
	while read -r line
	do
	    # add double qoutoes in the file to use spaces inside the column
	    # Check if line starts with #
	    if expr "${line}" : '#.*' > /dev/null; then
	       # echo Ignoring comment line
	    else
	       echo ${line} | xargs $0 $LEVEL BACKUP 
	    fi
	done < /usr/local/etc/${NAME}tab
esac

exit $rc
