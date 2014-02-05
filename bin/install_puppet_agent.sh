#!/bin/bash
set -e

### This script installs Puppet agent and facter on Ubuntu.

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit
fi

DEBIAN_FRONTEND=noninteractive
PUPPET_VERSION=${PUPPET_VERSION:-"3.4.2-1puppetlabs1"}
FACTER_VERSION=${FACTER_VERSION:-"1.7.4-1puppetlabs1"}

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
  DEB=$(mktemp -p /tmp puppetlabs-release.deb.XXXXXXXX)
  apt-get -y purge $(dpkg -l|grep puppet|awk '{print $2}')
  apt-get -y install wget
  wget -q http://apt.puppetlabs.com/puppetlabs-release-$(lsb_release -c -s).deb -O $DEB
  dpkg -i $DEB
  apt-get update
  apt-get -y install facter=$FACTER_VERSION puppet=$PUPPET_VERSION puppet-common=$PUPPET_VERSION vim-puppet=$PUPPET_VERSION
fi
