#!/bin/bash
export PATH=$PATH:/var/lib/gems/1.8/gems/fpm-1.0.1/bin

VERSION=${VERSION:-"1.0"}
PREFIX=${PREFIX:-"/opt"}
CHDIR=${CHDIR:-"build"}
TYPE="deb"
SOURCE="dir"
BASE_NAME=${JOB_NAME#"build-"}
EMAIL="Photobox Core Team <core@photobox.com>"
URL="http://www.photobox.com"
VENDOR="Photobox"
SCRIPTS_DIR="./package-scripts"

[ -f "$SCRIPTS_DIR/postinst" ] && SCRIPTS+="--post-install $SCRIPTS_DIR/postinst "
[ -f "$SCRIPTS_DIR/postrm" ] && SCRIPTS+="--post-uninstall $SCRIPTS_DIR/postrm "
[ -f "$SCRIPTS_DIR/preinst" ] && SCRIPTS+="--before-install $SCRIPTS_DIR/preinst "
[ -f "$SCRIPTS_DIR/prerm" ] && SCRIPTS+="--before-uninstall $SCRIPTS_DIR/prerm "

. ./package-scripts/control.sh

fpm -C $CHDIR -t $TYPE -s $SOURCE -n $BASE_NAME -v $VERSION --prefix $PREFIX $DEPENDS $RECOMMENDS $SCRIPTS --description "$DESCRIPTION" -m "$EMAIL" --vendor $VENDOR --url $URL $1
