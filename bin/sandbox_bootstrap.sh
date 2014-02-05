#!/bin/bash
set -e

# This script performs a check of the host's networking configuration a host to
# ensure it conforms to sandbox specification. If the check passes it installs
# the standard version of puppet & facter for babel, checks out the babel
# Puppet code and executes it. The end result should be the Photobox website
# running on the machine.

PUPPET_REPO=${PUPPET_REPO:-prod}
SITENAME=${SITENAME:-uktechnology}

HOSTNAME_RX='^[a-z\-]+-sandbox[1-9]?(\.core)?\.photobox\.(priv|com)$'

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

if [ -z "$SVN_USER" -o -z "$SVN_PASSWORD" ]; then
  usage
fi

apt-get update
apt-get -y install dnsutils wget subversion

MY_HOSTNAME=$(hostname -f)
if ! ( echo $MY_HOSTNAME|grep -qiP $HOSTNAME_RX ); then
  echo "Hostname must be of the form $HOSTNAME_RX, resolve this before continuing"
  exit 1
fi

if [[ -z "$(dig +short $MY_HOSTNAME)" ]]; then
  echo "No A record exists for $MY_HOSTNAME, resolve this before continuing"
  exit 1
fi

wget -q https://raw.github.com/photobox/basic-bootstraps/master/bin/install_puppet_agent.sh -O - | bash

DIR=puppet_svn
SVN_URL="http://svn.core.photobox.com/babel/handsfree/puppet/$PUPPET_REPO"
SVN_OPTS="--username $SVN_USER --password $SVN_PASSWORD --no-auth-cache"
echo "Checking out $SVN_URL to $DIR"

if [ -d $DIR ] && svn info $DIR 2>/dev/null; then
  svn switch $SVN_URL $SVN_OPTS $DIR
else
  [ -e $DIR ] && mv $DIR $DIR.backup.$$
  svn co $SVN_URL $DIR $SVN_OPTS
fi

cd $DIR
FACTER_SITENAME=$SITENAME puppet apply  --pluginsync --detailed-exitcodes manifests/site.pp --modulepath=modules --confdir=.

echo "Installation has completed, calling the frontend /status page"
curl http://localhost/status
echo

echo "If the status pages look correct try accessing the Photobox website at http://$MY_HOSTNAME/"
