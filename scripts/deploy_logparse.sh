#! /bin/sh
### Complete deployement after files cloned or unpacked 
#   Tested components on SASESCCLDVAPP01. ACF 27Feb2020
#   Use source to assign values to APPHOME, VER, LOGDIR
source $APPHOME/reffiles/logparse.env

#   Replace any existing symlink with link to latest version
mv saslogparse logparse$VER
if [ -L $APPHOME ]
then rm $APPHOME
     ln -s ${APPHOME}$VER $APPHOME
fi

#  Create other dirs if not exist
for DIR in joblogs/ packages/ refdata/ rejects/ sasdata/ saslogs/ sasprint/ 
do if ! [ -e $APPHOME/$DIR ] 
then 
mkdir $APPHOME/$DIR 
fi
done

# Users can write but not read logfiles. $SERVICEACCT can read but not write
if [ -O $LOGSDIR ]
then 
chmod 753 $LOGSDIR
else 
echo Cannot chmod  753 $LOGSDIR - Not owned by $USER
fi

# If DAYOLD=0 for immediate processing, then $SERVICEACCT needs to check if active PID is using $LOG
if ! [[ $(sudo -l | grep fuser) ]]    # If no access already, then append to sudoers
then sudo echo $SERVICEACCT ALL=(root) NOPASSWD: /usr/sbin/fuser * >> /etc/sudoers
fi
cd $CWD
