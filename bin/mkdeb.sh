#!/bin/bash
export PATH=$PATH:/var/lib/gems/1.8/gems/fpm-1.0.1/bin

VERSION=${VERSION:-"1.0"}
PREFIX=${PREFIX:-"/opt"}
TYPE="deb"
SOURCE="dir"
BASE_NAME=${JOB_NAME#"build-"}
fpm -C build -t $TYPE -s $SOURCE -n $BASE_NAME -v $VERSION --prefix $PREFIX $1

