#!/bin/bash
set -e
export PATH=$PATH:/var/lib/gems/1.8/gems/fpm-1.0.1/bin

[ -n "$PACKAGE_NAME" ] || { echo '$PACKAGE_NAME unset'; exit 1; }
[ -n "$INSTALL_PREFIX" ] || { echo '$INSTALL_PREFIX unset'; exit 1; }
[ -n "$JENKINS_BUILD_NUMBER" ] || { echo '$JENKINS_BUILD_NUMBER unset'; exit 1; }

PAYLOAD_DIR=${PAYLOAD_DIR:-"build"}
AUTO_VERSION="$JENKINS_BUILD_NUMBER-$(date -u +'%Y%m%d%H%M%S')r$(svnversion $PAYLOAD_DIR)"
VERSION=${VERSION:-$AUTO_VERSION}
SCRIPTS_DIR=${SCRIPTS_DIR:-"package-scripts"}
TYPE="deb"
SOURCE="dir"
EMAIL="Photobox Core Team <core@photobox.com>"
URL="http://www.photobox.com"
VENDOR="Photobox"

TMPDIR=$(mktemp -p . -d deb.XXXXXXXXXX)
cd $TMPDIR
PAYLOAD_DIR="../$PAYLOAD_DIR"
SCRIPTS_DIR="../$SCRIPTS_DIR"

[ -f "$SCRIPTS_DIR/postinst" ] && SCRIPTS+="--post-install $SCRIPTS_DIR/postinst "
[ -f "$SCRIPTS_DIR/postrm" ] && SCRIPTS+="--post-uninstall $SCRIPTS_DIR/postrm "
[ -f "$SCRIPTS_DIR/preinst" ] && SCRIPTS+="--before-install $SCRIPTS_DIR/preinst "
[ -f "$SCRIPTS_DIR/prerm" ] && SCRIPTS+="--before-uninstall $SCRIPTS_DIR/prerm "

. $SCRIPTS_DIR/control.sh

fpm -C $PAYLOAD_DIR -t $TYPE -s $SOURCE -n $PACKAGE_NAME -v $VERSION --prefix $INSTALL_PREFIX $DEPENDS $RECOMMENDS $SCRIPTS --description "$DESCRIPTION" -m "$EMAIL" --vendor $VENDOR --url $URL $FPM_EXTRA_FLAGS .

REPO_HOST=${REPO_HOST:-"proj.photobox.co.uk"}
BASE_REPO_PATH=${BASE_REPO_PATH:-"/install/repo/apt"}
REPO_INJECT_COMMAND=${REPO_INJECT_COMMAND:-"/handsfree/scripts/debrepo_simple.pl"}

for release in $UBUNTU_RELEASES; do
  REPO_PATH="$BASE_REPO_PATH/$release"
  scp *.deb $REPO_HOST:$REPO_PATH/binary
  [ "$release" == "lucid" ] && ssh -n $REPO_HOST /handsfree/scripts/purge_debs.pl -v
  ssh -n $REPO_HOST $REPO_INJECT_COMMAND -r $REPO_PATH -d binary
done

rm *.deb
cd ..
rmdir $TMPDIR
