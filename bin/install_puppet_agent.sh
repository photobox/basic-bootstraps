#!/bin/bash
set -e

### This script installs Puppet agent and facter

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit
fi

OS_IS_REDHAT=false
if [ -f /etc/redhat-release ]; then
  OS_IS_REDHAT=true
fi

if $OS_IS_REDHAT; then
  DEFAULT_PUPPET_VERSION="3.7.4-1.el6"
  DEFAULT_FACTER_VERSION="2.4.1-1.el6"
else
  DEFAULT_PUPPET_VERSION="3.7.4-1puppetlabs1"
  DEFAULT_FACTER_VERSION="2.4.1-1puppetlabs1"
fi

PUPPET_VERSION=${PUPPET_VERSION:-$DEFAULT_PUPPET_VERSION}
FACTER_VERSION=${FACTER_VERSION:-$DEFAULT_FACTER_VERSION}

have_version(){
  local PACKAGE=$1
  local VERSION=$2
  if $OS_IS_REDHAT; then
    if [[ "$(rpm -qa --queryformat '%{VERSION}-%{RELEASE}' ${PACKAGE})" == "${VERSION}" ]]; then
      return 0
    fi
    return 1
  else
    if [[ "$(dpkg-query -W -f='${Version}' ${PACKAGE})" == "${VERSION}" ]] && [[ "$(dpkg-query -W -f='${Status}' ${PACKAGE}|perl -lane 'print $F[-1]')" == "installed" ]]; then
      return 0
    fi
    return 1
  fi
}

puppet_is_current(){
  have_version puppet $PUPPET_VERSION || return 1
  have_version facter $FACTER_VERSION || return 1
  if ! $OS_IS_REDHAT; then
    have_version puppet-common $PUPPET_VERSION || return 1
  fi
  return 0
}

if ! puppet_is_current; then
  if $OS_IS_REDHAT; then
    rpm -U --quiet http://yum.puppetlabs.com/puppetlabs-release-el-$(lsb_release -rs|cut -d. -f1).noarch.rpm || true
    yum -y install facter-$FACTER_VERSION puppet-$PUPPET_VERSION
  else
    DEBIAN_FRONTEND=noninteractive
    DEB=$(mktemp -p /tmp puppetlabs-release.deb.XXXXXXXX)
    apt-get -y purge $(dpkg -l|grep puppet|awk '{print $2}')
    apt-get -y install wget
    wget -q http://apt.puppetlabs.com/puppetlabs-release-$(lsb_release -c -s).deb -O $DEB
    dpkg -i $DEB
    apt-get update
    apt-get -y install facter=$FACTER_VERSION puppet=$PUPPET_VERSION puppet-common=$PUPPET_VERSION vim-puppet=$PUPPET_VERSION
  fi
fi

# Debian packages still specify 'templatedir' in the client config file which
# leads to annoying deprecation warnings
sed -i '/templatedir/d' /etc/puppet/puppet.conf
