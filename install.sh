#!/bin/bash
#
# Mail Server Configuration
#
# Copyright (C) 2014
#
# Author: Raisul Islam
# This program is not Free
############################################################

yum -y install wget chkconfig

echo -e "Centos 6 Mail Server Automated Installer\n\n"
echo -e "This script assumes you have installed Centos 6 as either Minimal or Basic Server.\n"
echo -e "If you selected additional options during the CentOS install please consider reinstalling with no additional options.\n\n"


#################################
####  variables #################
#################################
#################################
TEMP_USER_ANSWER="no"
WWWDIR=/var/www
MYSQL_ROOT_PASSWORD=""
fqdn=`/bin/hostname`


#################################
#################################
####  general functions #########
#################################
#################################

# task of function: ask to user yes or no
# usage: ask_to_user_yes_or_no "your question"
# return TEMP_USER_ANSWER variable filled with "yes" or "no"
ask_to_user_yes_or_no () {
	# default answer = no
	TEMP_USER_ANSWER="no"
	clear
	echo ""
	echo -e ${1}
	read -n 1 -p "(y/n)? :"
	if [ ${REPLY} = "y" ]; then
		TEMP_USER_ANSWER="yes"
	else
		TEMP_USER_ANSWER="no"
	fi
}

# Determine the OS architecture
get_os_architecture () {
	if [ ${HOSTTYPE} == "x86_64" ]; then
		ARCH=x64
	else
		ARCH=x32
	fi
}
get_os_architecture

# Linux Distribution CentOS or Debian
get_linux_distribution () {
	if [ -f /etc/debian_version ]; then
		DIST="DEBIAN"
	elif  [ -f /etc/redhat-release ]; then
		DIST="CENTOS"
	else
		DIST="OTHER"
	fi
}
get_linux_distribution

# get ip of eth0
get_local_ip () {
LOCAL_IP=`ifconfig eth0 | head -n2 | tail -n1 | cut -d' ' -f12 | cut -c 6-`
}
get_local_ip

install_epel () {
# only on CentOS
	if [ ${ARCH} = "x64" ]; then
		rpm -Uvh http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
	else
		rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
	fi
}


#################################
#################################
#### INSTALL PREREQUISITEN ######
#################################
#################################

echo -e "## Removing sendmail and vsftpd"
yum -y remove sendmail vsftpd
#echo -e "## Running System Update ##";
#yum -y update
echo -e "## Installing vim make zip unzip ld-linux.so.2 libbz2.so.1 libdb-4.7.so libgd.so.2 ##"
yum -y install sudo wget vim make zip unzip git ld-linux.so.2 libbz2.so.1 libdb-4.7.so libgd.so.2
echo -e "## Installing httpd php php-suhosin php-devel php-gd php-mbstring php-mcrypt php-intl php-imap php-mysql php-xml php-xmlrpc curl curl-devel perl-libwww-perl libxml2 libxml2-devel mysql-server zip webalizer gcc gcc-c++ httpd-devel at make mysql-devel bzip2-devel ##"
yum -y -q install httpd php php-suhosin php-devel php-gd php-mbstring php-mcrypt php-intl php-imap php-mysql php-xml php-xmlrpc curl curl-devel perl-libwww-perl libxml2 libxml2-devel mysql-server zip webalizer gcc gcc-c++ httpd-devel at make mysql-devel bzip2-devel
echo -e "## Installing postfix dovecot dovecot-mysql ##"
yum -y install postfix dovecot dovecot-mysql
echo -e "## Installing proftpd proftpd-mysql ##"
yum -y install proftpd proftpd-mysql
echo -e "## Installing bind bind-utils bind-libs ##"
yum -y install bind bind-utils bind-libs


#################################
#################################
####  ASK SCRIPTS ###############
#################################
#################################


# Ask to install Custom Mail Server Service
ask_to_install_cmss () {
  
	ask_to_user_yes_or_no "Do you want to upgrade CMSS?"
	echo -e "";
	  ask_to_user_yes_or_no "Do you want to install CMSS?"
	  if 	[ ${TEMP_USER_ANSWER} = "yes" ]; then
		read -e -p "Enter the FQDN of the server (example: mail.yourdomain.com): " -i $fqdn fqdn
	fi
}
ask_to_install_cmss


#################################
#################################
####  INSTALL SCRIPTS ###########
#################################
#################################

clear



###################    
# CONFIGURE MYSQL #
###################
echo -e "## CONFIGURE MYSQL ##"
chkconfig --levels 235 mysqld on
service mysqld start
read -p "Enter the password for mysql: "
MYSQL_ROOT_PASSWORD=${REPLY}
mysqladmin -u root password ${MYSQL_ROOT_PASSWORD}
mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "DROP DATABASE test";
read -p "Remove access to root MySQL user from remote connections? (Recommended) Y/n " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "DELETE FROM mysql.user WHERE User='root' AND Host!='localhost'";
echo "Remote access to the root MySQL user has been removed"
else
echo "Remote access to the root MySQL user is still available, we hope you selected a very strong password"
fi
mysql -u root -p{MYSQL_ROOT_PASSWORD} -e "DELETE FROM mysql.user WHERE User=''";
mysql -u root -p{MYSQL_ROOT_PASSWORD} -e "FLUSH PRIVILEGES";



###########################################
# POSTFIX-DOVECOT (CentOS6 uses Dovecot2) #
###########################################
mkdir -p /var/cmss/vmail
chmod -R 777 /var/cmss/vmail
chmod -R g+s /var/cmss/vmail
groupadd -g 5000 vmail
useradd -m -g vmail -u 5000 -d /var/cmss/vmail -s /bin/bash vmail
chown -R vmail.vmail /var/cmss/vmail


