#! /bin/sh
### Append logparse scripts to crontab
if [ "$APPHOME" = "" ]
then APPHOME=/sasdata/bicoc_output01/monitoring/logparse
fi
# Save current crontab
crontab -l > $APPHOME/reffiles/crontab_$(date '+%Y%m%d').txt
# Append logparse jobs
echo "35 02 * * * $APPHOME/scripts/process_WSlogs.sh # Nightly logparse" >> $APPHOME/reffiles/crontab_$(date '+%Y%m%d').txt
echo "45 02 * * * $APPHOME/scripts/bkup_hskp_WSlogs.sh # Nightly logparse cleanup " >> $APPHOME/reffiles/crontab_$(date '+%Y%m%d').txt
# Load old and new entries to crontab
crontab $APPHOME/reffiles/crontab_$(date '+%Y%m%d').txt

echo Current crontab:
crontab -l
