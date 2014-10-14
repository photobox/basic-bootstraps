#!/bin/bash
#
set -e

export DEBIAN_FRONTEND=noninteractive

wget -q -O- --no-check-certificate https://raw.githubusercontent.com/photobox/basic-bootstraps/master/bin/install_puppet_agent.sh | bash

GIT="git-core"
[[ "$(lsb_release -rs)" > "10.04" ]] && GIT="git"

apt-get -qy install $GIT

cat <<EOF

---------------------------------------------------------------
Prequisites installed, now run:

  git clone git@github.com:photobox/babel_vdc_provisioning.git
  cd babel_vdc_provisioning
  sudo ./bin/install_bootstraps
---------------------------------------------------------------
EOF
