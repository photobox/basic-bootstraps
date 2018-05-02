#!/bin/bash
set -e

### This script installs Puppet agent and facter

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit
fi

PUPPET_VERSION="3.7.4-1puppetlabs1"
FACTER_VERSION="2.4.1-1puppetlabs1"

install_ubuntu(){
  export DEBIAN_FRONTEND=noninteractive
  local TMPDIR=$(mktemp -d)
  pushd ${TMPDIR}
  aws s3 sync s3://babel-instance-bootstrap/puppet/ .
  # NOTE: installing the packages with dpkg is expected to fail on deps, we fix
  # this up with `apt-get -yf` afterwards.
  dpkg -i \
    "puppet-common_${PUPPET_VERSION}"* \
    "puppet_${PUPPET_VERSION}"* \
    "facter_${FACTER_VERSION}"* \
    "hiera_1.3.4-1puppetlabs1"* \
    > /dev/null 2>&1 || true
  apt-get -yf install
  popd

  if puppet_is_current; then
    echo "Installation succeeded"
    exit 0
  else
    echo "Installation failed"
    exit 1
  fi
}

have_version(){
  local PACKAGE=$1
  local VERSION=$2
  if [[ "$(dpkg-query -W -f='${Version}' ${PACKAGE})" == "${VERSION}" ]] && [[ "$(dpkg-query -W -f='${Status}' ${PACKAGE}|perl -lane 'print $F[-1]')" == "installed" ]]; then
     return 0
  fi
  return 1
}

puppet_is_current(){
  have_version puppet $PUPPET_VERSION || return 1
  have_version facter $FACTER_VERSION || return 1
  return 0
}

if [ $(lsb_release -r -s) != '14.04' ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y puppet-common puppet facter hiera
elif ! puppet_is_current; then
  install_ubuntu
  # Debian packages still specify 'templatedir' in the client config file which
  # leads to annoying deprecation warnings
  sed -i '/templatedir/d' /etc/puppet/puppet.conf
fi
