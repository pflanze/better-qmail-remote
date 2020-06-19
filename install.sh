#!/bin/sh

INSTALL_DIR=`pwd`
echo "Make sure you have the RPMForge repo (or similar repository) installed"
echo "so we can get perl packages not normally available in the base repo."
echo 
echo "Now would also be a good time to send a message using your system to"
echo "make sure that you can in fact send emails before we modify the sending"
echo "mechanism."
echo
echo "Hit [enter] to continue...."
read LETSGO

# Install some needed perl modules
yum install perl-XML-Simple perl-Mail-DKIM perl-XML-Parser

# Let's create the directory we need for configuration
mkdir /var/qmail/control/dkim

# Generate our DKIM keys, both public and private
dknewkey /var/qmail/control/dkim/global.key > /var/qmail/control/dkim/public.txt
# or use opendkim-genkey as mentioned in README.md

# Change DKIM DNS selector value
perl -pi -e 's/global.key._domainkey/dkim1/' /var/qmail/control/dkim/public.txt

# Move the config file to the proper location
mv $INSTALL_DIR/signconf.xml /var/qmail/control/dkim/

# Set permissions on DKIM key files
#chown -R qmailr:qmail /var/qmail/control/dkim
#huh giving write access? rather:
chmod -R g+r /var/qmail/control/dkim
chgrp -R qmail /var/qmail/control/dkim

# Warn you and give you the correct DNS entry to sign messages
echo
echo "We have set up and configured DKIM up to a point. You now need to add the"
echo "DKIM entry to your DNS config. For BIND, here is the entry you need to"
echo "make into your DNS zone file:"
cat /var/qmail/control/dkim/public.txt
echo
echo "This script will configure your machine to sign *ALL* domains on this serves"
echo "to sign with this key. If you do not wish to sign all domains, you will need"
echo "to edit the /var/qmail/control/dkim/signconf.xml file to reflect this."
echo
echo
echo "At this point, outbound emails are not signed. When you are ready to"
echo "continue, hit [enter] and this script will stop qmail, replace the"
echo "qmail-remote file with the wrapper to sign messages, and then start"
echo "qmail back up."
echo
read LETSGO

# Stop qmail, mmove qmail-remote to qmail-remote.orig (*MUST* be this name! The
# wrapper e're replacing it with signs the message, then calls qmail-remote.orig
# to send the message out!
qmailctl stop
sleep 5
mv /var/qmail/bin/qmail-remote /var/qmail/bin/qmail-remote.orig
ln -s $INSTALL_DIR/qmail-remote /var/qmail/bin/

# Set permissions on the qmail-remote wrapper
#chmod 777 /var/qmail/bin/qmail-remote
# again, definitively NO. NOT at all.
chmod +x /var/qmail/bin/qmail-remote

chown root:qmail /var/qmail/bin/qmail-remote

qmailctl start
sleep 5

echo 
echo "A text file was created (/var/qmail/control/dkim/public.txt) that is the bind record that you"
echo "need to enter for all of your domains. All of your domains will be DKIM signed at this point."
echo


