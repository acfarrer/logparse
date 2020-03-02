#! /bin/sh
## Daily or hourly processing of WS logs using %logparse
#  bicocsas@sasebcclpradh01 crontab -l = 05 02 * * * /sasdata/bicoc_output01/monitoring/logparse/scripts/process_WSlogs.sh
#   Version 2       ACF   23Jan2020
#   Version 3  Deploying to sas@SASESCCLDVAPP01       ACF   27Jan2020
#   Version 4  Merge versions from sas@SASESCCLDVAPP01       ACF   11Feb2020
#   Version 4  Exclude processed logs from scan. Add listings       ACF   15Feb2020
#   Version 5  Consistent struture for $JOBLOG to drive exceptions, housekeeping and archive as root
if [ $USER = 'bicocsas' ] || [ $USER = 'sas' ]
then APPHOME=/sasdata/bicoc_output01/monitoring/logparse # Owned by sas
else APPHOME=$HOME           # For testing
fi

source $APPHOME/reffiles/logparse.env    # Contains export $DAYSOLD, $LOGSDIR
export APPHOME # For %sysget in SAS code one day
#DAYSOLD=0   # Assumes scheduled early morning
#DAYSOLD=+3   # Last modified days ago
SASEXE=/opt/sas/sashome/SASFoundation/9.4/sasexe/sas
SASPROG=logparse_usage_sysparm
# LOGSDIR=/sasdata/bicoc_output01/SASWSlogs # Now in logparse.env
SASCODE=$APPHOME/sascode
SASLOGS=$APPHOME/saslogs
JOBLOGS=$APPHOME/joblogs
REFDATA=$APPHOME/refdata
LOGLIST=$REFDATA/loglist_$(date '+%Y%m%d%H%M').lst
DONELST=$REFDATA/processed_logs.lst   # Updated after each log is processed
RUNDATE=$(date +%FT%T) # ISO8601 format can be read using SAS informat E8601DT23. Not great for bash - ':' interpreted as delimiter
# End of variables.

SCRPTNM=$(basename $0)    # Use bare script name for job log name
JOBLOG=$JOBLOGS/${SCRPTNM%.sh}_$RUNDATE.log
TMPLIST=$(mktemp)         # exists for duration of script process
/usr/bin/find $LOGSDIR -mtime $DAYSOLD -type f -name "*.log"        > $TMPLIST
echo Rundate=$RUNDATE Apphome=$APPHOME Daysold=$DAYSOLD User=$USER >> $JOBLOG
echo $LOGLIST is latest logs for processing                        >> $JOBLOG
# Exclude logs already processed 
/usr/bin/grep -v -f $DONELST $TMPLIST                               > $LOGLIST
#  Loop thru list. Run %logparse against each
for LOG in $(cat $LOGLIST) 
#  () forces sub-process with different $BASHPID . 26Jan2020 ACF
do ( 
  OWNRPID=$(sudo /usr/sbin/fuser $LOG | cut -d ' ' -f2) # fuser only works after modifying /etc/sudoers
  if ! [ "$OWNRPID" = "" ] 
    then echo RC=6 $LOG in use by $OWNRPID                         >> $JOBLOG 2>&1
# Basic check of log layout as defined by ConversionPattern in logconfig.altlog.xml
  elif [ $(head -1 $LOG | cut -c 1-5) != START ]    # First 5 bytes should eq 'START'
    then echo RC=8 $LOG                                            >> $JOBLOG 2>&1
    exit 2                                          # Stop this iteration of for loop
  else
    SASLOG=$SASLOGS/logparse_$(date +'%Y%m%d')_$BASHPID.log
    $SASEXE -sysin $SASCODE/$SASPROG.sas -log $SASLOG -sysparm $LOG
    RC=$?                                           # sas process returns 0,1,2 reliably
    echo RC=$RC $SASLOG -sysparm $LOG                              >> $JOBLOG
  fi
# when using crontab, echo to standard output goes to mailx body
  if   [ $RC -eq 0 ] 
  then 
    echo RC=$? Completed OK $SASPROG
  elif [ $RC -eq 1 ] 
  then
    echo RC=$RC Warnings. From $SASLOG :
    /usr/bin/grep WARN $SASLOG
  else 
    echo RC=$RC Problems. From $SASLOG :
    /usr/bin/grep WARN $SASLOG
    /usr/bin/grep ERR $SASLOG
  fi
   )  # End of sub-process 
done
# More useful info for mailx
echo
echo $(cat $DONELST | wc -l) logs already processed are in $DONELST 
for LOG in $(cat $DONELST) ; do stat -c '%A %U %s %.10y %n' $LOG ; done
echo
echo $(cat $TMPLIST | wc -l) *.logs matching -mtime $DAYSOLD are in $TMPLIST
for LOG in $(cat $TMPLIST) ; do stat -c '%A %U %s %.10y %n' $LOG ; done
echo
echo $(cat $LOGLIST | wc -l) *.logs to be processed on $RUNDATE are in $LOGLIST
for LOG in $(cat $LOGLIST) ; do stat -c '%A %U %s %.10y %n' $LOG ; done
echo
echo Joblog is $JOBLOG
# Nightly, $JOBLOG is scanned to drive exceptions, housekeeping and archive as root
cat $JOBLOG
