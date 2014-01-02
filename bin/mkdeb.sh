#!/bin/bash
export PATH=$PATH:/var/lib/gems/1.8/gems/fpm-1.0.1/bin

PREFIX=${PREFIX:-"/opt"}
VERSION=${VERSION:-"1.0"}
PREFIX=${PREFIX:-"/opt"}
TYPE="deb"
SOURCE="dir"

fpm -t $TYPE -s $SOURCE -n $NAME -v $VERSION --prefix $PREFIX $1
