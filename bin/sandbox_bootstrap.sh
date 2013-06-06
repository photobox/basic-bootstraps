#!/bin/bash
set -e

### This script gets a basic machine to state where Puppet can install a babel sandbox

PUPPET_REPO=${PUPPET_REPO:-prod}
SITENAME=${SITENAME:-uktechnology}

HOSTNAME_RX='^[a-z]+-sandbox[1-9]?\.photobox\.priv$'
IP_ADDRESS_RX='^10\.5\.16\.[0-9]+$'

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit
fi

usage(){
  echo "USAGE: PUPPET_REPO=<repo> SVN_USER=<user> SVN_PASSWORD=<password> SITENAME=<sitename> $0"
  exit
}

if [ -z "$PUPPET_REPO" ]; then
  echo "Set puppet repo eg 'jira/WEB-1234'"
  usage
fi

if [ -z "$SVN_USER" -o -z "$SVN_PASSWORD" -o -z "$SITENAME" ]; then
  usage
fi

MY_HOSTNAME=$(hostname -f)
if ! ( echo $MY_HOSTNAME|grep -qP $HOSTNAME_RX ); then
  echo "Hostname must be of the form $HOSTNAME_RX, resolve this before continuing"
  exit 1
fi

MY_ADDRESS=$(ip -o addr list dev eth0 primary|perl -nE 'print $1 if m#inet ([^/]+)#')
if ! ( echo $MY_ADDRESS|grep -qP $IP_ADDRESS_RX ); then
  echo "The IP address for this host ($MY_ADDRESS) does not match $IP_ADDRESS_RX, resolve this before continuing"
  exit 1
fi

if [[ -z "$(dig +short A $MY_HOSTNAME)" ]]; then
  echo "No A record exists for $MY_HOSTNAME, resolve this before continuing"
  exit 1
fi

MY_A_RECORD=$(dig +short A $MY_HOSTNAME)
if [[ "$MY_A_RECORD" != $MY_ADDRESS ]]; then
  echo "The A record for $MY_HOSTNAME ($MY_A_RECORD) does not match its IP address ($MY_ADDRESS), resolve this before continuing"
  exit 1
fi

apt-get -y install dnsutils wget subversion
wget -q https://raw.github.com/photobox/basic-bootstraps/master/bin/install_puppet_agent.sh -O - | bash

DIR=puppet_svn
SVN_URL="http://svn.photobox.co.uk/babel/handsfree/puppet/$PUPPET_REPO"
SVN_OPTS="--username $SVN_USER --password $SVN_PASSWORD --no-auth-cache"
echo "Checking out $SVN_URL to $DIR"

if [ -d $DIR ] && svn info $DIR 2>/dev/null; then
  svn switch $SVN_URL $SVN_OPTS $DIR
else
  [ -e $DIR ] && mv $DIR $DIR.backup.$$
  svn co $SVN_URL $DIR $SVN_OPTS
fi

cd $DIR
FACTER_SITENAME=$SITENAME puppet apply manifests/site.pp --modulepath=modules
