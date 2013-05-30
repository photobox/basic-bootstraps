#!/bin/bash
set -e

### This script installs Puppet agent and facter on Ubuntu.

if [[ "$(whoami)" != "root" ]]; then
  echo "Must be run as root"
  exit
fi

PUPPET_VERSION=${PUPPET_VERSION:-"2.7.21-1puppetlabs1"}
FACTER_VERSION=${FACTER_VERSION:-"1.7.0-1puppetlabs1"}

have_version(){
  local PACKAGE=$1
  local VERSION=$2
  if [[ "$(dpkg-query -W -f='${Version}' $PACKAGE)" == "$VERSION" ]] && [[ "$(dpkg-query -W -f='${Status}' $PACKAGE|perl -lane 'print $F[-1]')" == "installed" ]]; then
    return 0
  fi
  return 1
}

puppet_is_current(){
  have_version puppet $PUPPET_VERSION || return 1
  have_version puppet-common $PUPPET_VERSION || return 1
  have_version facter $FACTER_VERSION || return 1
  return 0
}

if ! puppet_is_current; then
  (
    TMPDIR=$(mktemp -d -p /tmp puppetinstall.XXXXXXXX)
    cd $TMPDIR
    apt-get -y purge $(dpkg -l|grep puppet|awk '{print $2}')
    apt-get -y install wget
    DEB="puppetlabs-release-$(lsb_release -c -s).deb"
    wget -q http://apt.puppetlabs.com/$DEB -O $DEB
    dpkg -i $DEB
    apt-get update
    apt-get -y install facter=$FACTER_VERSION puppet=$PUPPET_VERSION puppet-common=$PUPPET_VERSION subversion vim-puppet=$PUPPET_VERSION
  )
fi
