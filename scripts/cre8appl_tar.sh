#! /bin/sh
### Create or deploy package of folder
#   Tested components on SASESCCLDVAPP01. ACF 27Feb2020
#   Use source to assign values to APPHOME, VER, LOGDIR
source ./reffiles/logparse.env

#   Packaging steps assumes $APPHOME exists with matching $VER
if [ -e $APPHOME ] && [ -e $APPHOME/reffiles/logparse_components_${VER}.lst ]
then
#  Create tarball based on components list for $VER
/usr/bin/tar -cvf $APPHOME/packages/logparse_app${VER}.tar $(cut -d ' ' -f1 $APPHOME/reffiles/logparse_components_${VER}.lst)
echo List of contents :
/usr/bin/tar -tvf $APPHOME/packages/logparse_app${VER}.tar

else
#   Deployment steps
#   cd to parent of target location 
CWD=$PWD
cd $APPHOME/..

# For Dev only. Will create $APPHOME/saslogparse
if [ -x git ]
then 
git clone https://bitbucket.bmogc.net/scm/sasenv/saslogparse.git
# Use tar for Prod until bitbucket connected
elif [ $(hostname -s ) = sasebcclpradh01 ] || [ $(hostname -s ) = sasebcclprsch01 ]
then 
/usr/bin/tar -xvf $APPHOME/packages/logparse_app${VER}.tar -C $APPHOME # May need to add --strip-components 2
else
echo Cannot deploy using this script
fi

#   Replace any existing symlink with link to latest version
mv saslogparse logparse$VER
if [ -L $APPHOME ]
then rm $APPHOME
     ln -s ${APPHOME}$VER $APPHOME
fi

echo Deployed files :
find $APPHOME -ls

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
then sudo echo “$SERVICEACCT ALL=(root) NOPASSWD: /usr/sbin/fuser * “ >> /etc/sudoers
fi
cd $CWD
