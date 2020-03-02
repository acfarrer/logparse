#! /bin/sh
### Manage logfiles in WSLogs, and SAS datasets in $APPHOME/sasdata
#   Archive (gzip) or move WSLogs based on RC from process_WSlogs.sh. To be run by root
#   Version 1       ACF   18Feb2020
#   Version 2 Tested ACF  21Feb2020
if [ $USER = 'bicocsas' ]
then APPHOME=/sasdata/bicoc_output01/monitoring/logparse # Owned by bicicsas
elif [ $USER = 'sas' ]
then APPHOME=/sasdata/bicoc_output01/monitoring/logparse # Owned by sas
else APPHOME=$HOME           # For testing
fi
JOBLOGS=$APPHOME/joblogs
REFDATA=$APPHOME/refdata
RUNDATE=$(date +%FT%T) # ISO8601 format can be read using SAS informat E8601DT23. Not great for bash - ':' interpreted as delimiter
SCRPTNM=$(basename $0)    # Use bare script name for job log name
JOBLOG=$JOBLOGS/${SCRPTNM%.sh}_$RUNDATE.log
#  End of variables.
#  Local functions
archive ()
{
  if [ -e ${1}.gz ]
  then echo No archive as ${1}.gz exists  
  else 
    /usr/bin/tar -pzcvf ${1}.gz $1 
    if [ $? -eq 0 ] 
    then rm $1 
    else echo Problem from tar of $1 RC=$? 
    fi
  fi
}
reject ()
{
  WSLOG=$1
  if [ -e $WSLOG ]
  then /usr/bin/mv $1 $APPHOME/rejects/${WSLOG##*/}
    if [ $? -eq 0 ] 
      then ls -al $APPHOME/rejects/${WSLOG##*/}
      else echo Problem trying to mv $WSLOG RC=$?
    fi
  else echo Cannot mv non-existing file $WSLOG
  fi
}
#  End of local functions
#  Remove *.gz older than 5 days
echo SASWS logs older than 5 days   >> $JOBLOG
/usr/bin/find $LOGSLOC -mtime +5 -name "*.gz" -ls >> $JOBLOG 2>&1
#/usr/bin/find $LOGLOC -mtime +5 -name "*.gz" -delete
echo Joblog is $JOBLOG

### Archive or move WSLogs based on RC from process_WSlogs.sh. To be run by root
LASTLOG=$(ls -1rt $APPHOME/joblogs/process_WSlogs_* | tail -1)
#  Cannot get IFS=$'\n' and < "$(grep ^RC= $OUTLOG)" to work
RCLIST=$(mktemp)
#  Filter valid lines starting with 'RC=' to tempfile
grep ^RC= $LASTLOG > $RCLIST 
# while read var ; do; done < file default delimiter is line not space
while IFS= read -r LINE 
do
  read -r RCEQ SASLOG SYSPARM LOGNAME <<< "$LINE"
  RC=${RCEQ:3:1}     # Index starts at 0 to exclude 'RC='
  if   [ $RC -eq 0 ] ; then archive $LOGNAME 
  elif [ $RC -eq 8 ] ; then reject $SASLOG
  else echo Investigate $SASLOG RC=$RC
  fi
done < "$RCLIST"
