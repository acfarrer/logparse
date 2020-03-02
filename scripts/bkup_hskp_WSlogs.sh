#! /bin/sh
## Daily or hourly processing of WS logs using %logparse
#  bicocsas@sasebcclpradh01 crontab -l = 05 02 * * * /sasdata/bicoc_output01/monitoring/logparse/scripts/bkup_hskp_WSlogs.sh
#   Version 1       ACF   26Jan2020
#   Version 2.1       ACF   31Jan2020
if [ $USER = 'bicocsas' ]
then APPHOME=/sasdata/bicoc_output01/monitoring/logparse # Owned by bicicsas
elif [ $USER = 'sas' ]
then APPHOME=/sasdata/bicoc_output01/monitoring/logparse # Owned by sas
else APPHOME=$HOME           # For testing
fi
export APPHOME # For %sysget in SAS code
SASEXE=/opt/sas/sashome/SASFoundation/9.4/sasexe/sas
SASCODE=$APPHOME/sascode
SASLOGS=$APPHOME/saslogs
JOBLOGS=$APPHOME/joblogs
REFDATA=$APPHOME/refdata
RUNDATE=$(date +%FT%T) # ISO8601 format can be read using SAS informat E8601DT23. Not great for bash - ':' interpreted as delimiter
SCRPTNM=$(basename $0)    # Use bare script name for job log name
JOBLOG=$JOBLOGS/${SCRPTNM%.sh}_$RUNDATE.log
# End of variables.

# Runs proc datasets: Create copy_yymmdd, delete copy_yymmdd - 8
$SASEXE -sysin $SASCODE/logdata_bkup_hskp.sas -log $SASLOGS/logdata_bkup_hskp_$(date +'%Y%m%d')_$BASHPID.log #>> $JOBLOG 2>&1
if [ $? -gt 0 ] 
  then echo RC=$? . Problems with $SASPROG >> $JOBLOG 2>&1
  exit 1  # Stop next step 
fi
  
#  Remove *.gz older than 5 days
echo SASWS logs older than 5 days   >> $JOBLOG
/usr/bin/find /sasdata/bicoc_output01/SASWSlogs -mtime +5 -name "*.gz" -ls >> $JOBLOG 2>&1
#/usr/bin/find /sasdata/bicoc_output01/SASWSlogs -mtime +5 -name "*.gz" -delete
echo Joblog is $JOBLOG

