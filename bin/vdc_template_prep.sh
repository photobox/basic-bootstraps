#!/bin/bash
#
set -e

xlog(){
  echo "$(date -u +%FT%T.%6NZ) [vdc_nethack] $1"
  #logger -t vdc_nethack $1
}

export DEBIAN_FRONTEND=noninteractive

[ -n "${GITHUB_USER}" ] || { echo "GITHUB_USER unset"; exit 1; }
[ -n "${GITHUB_PASSWORD}" ] || { echo "GITHUB_PASSWORD unset"; exit 1; }

wget -q -O- --no-check-certificate https://raw.githubusercontent.com/photobox/basic-bootstraps/master/bin/install_puppet_agent.sh | bash

GIT="git-core"
[[ "$(lsb_release -rs)" > "10.04" ]] && GIT="git"

apt-get -y install $GIT

WORKDIR=$(mktemp -d)
cd $WORKDIR

git clone https://${GITHUB_USER}:${GITHUB_PASSWORD}@github.com/photobox/babel_vdc_provisioning.git

puppet apply --modulepath modules default.pp
