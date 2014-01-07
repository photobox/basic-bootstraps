#!/usr/bin/env bash
set -e

FPM='/var/lib/gems/1.8/gems/fpm-1.0.1/bin/fpm'

if [[ "$MAKE_PACKAGE" == "false" ]]; then
  echo 'Not building package because $MAKE_PACKAGE is "false"'
  exit 0
fi

function bail {
    echo $1;
    exit 1;
}

[ -n "${PACKAGE_NAME}" ]   || bail '$PACKAGE_NAME unset';
[ -n "${PAYLOAD_DIR}" ]    || bail '$PAYLOAD_DIR unset';
[ -n "${BUILD_NUMBER}" ]   || bail 'Jenkins envvar $BUILD_NUMBER unset';

VERSION=${VERSION:-"1.2"}
PACKAGE_VERSION="${VERSION}-${BUILD_NUMBER}-$(date -u +'%Y%m%d%H%M%S')r$(svnversion $PAYLOAD_DIR)"
SCRIPTS_DIR=${SCRIPTS_DIR:-'package-scripts'}
INSTALL_PREFIX=${INSTALL_PREFIX:+"--prefix $INSTALL_PREFIX"}
TYPE='deb'
SOURCE='dir'
EMAIL='Photobox Core Team <core@photobox.com>'
URL='http://www.photobox.com'
VENDOR='Photobox'
DESCRIPTION='Boilerplate - please set $DESCRIPTION in control.sh
Boilerplate long description'

TMPDIR=$(mktemp -p . -d deb.XXXXXXXXXX)
cd $TMPDIR
PAYLOAD_DIR="../${PAYLOAD_DIR}"
SCRIPTS_DIR="../${SCRIPTS_DIR}"

[ -f "${SCRIPTS_DIR}/postinst" ] && SCRIPTS+="--after-install ${SCRIPTS_DIR}/postinst "
[ -f "${SCRIPTS_DIR}/postrm" ] && SCRIPTS+="--after-remove ${SCRIPTS_DIR}/postrm "
[ -f "${SCRIPTS_DIR}/preinst" ] && SCRIPTS+="--before-install ${SCRIPTS_DIR}/preinst "
[ -f "${SCRIPTS_DIR}/prerm" ] && SCRIPTS+="--before-remove ${SCRIPTS_DIR}/prerm "

. $SCRIPTS_DIR/control.sh

for i in $DEPENDS; do
  DEPENDS_AS_OPTS+="-d ${i} "
done

for i in $CONFLICTS; do
  CONFLICTS_AS_OPTS+="--conflicts ${i} "
done

for i in $RECOMMENDS; do
  RECOMMENDS_AS_OPTS+="--deb-recommends ${i} "
done

# Append packages that this package was built against to the package description if a build.info file is present in $PAYLOAD DIR
[ -f $PAYLOAD_DIR/build.info ] && DESCRIPTION+="
This package was built against:
$(< $PAYLOAD_DIR/build.info)"

$FPM -C $PAYLOAD_DIR -t $TYPE -s $SOURCE -n $PACKAGE_NAME -v $PACKAGE_VERSION $INSTALL_PREFIX $DEPENDS_AS_OPTS $CONFLICTS_AS_OPTS $RECOMMENDS_AS_OPTS $SCRIPTS --description "$DESCRIPTION" -m "$EMAIL" --vendor $VENDOR --url $URL $FPM_EXTRA_FLAGS .

REPO_HOST=${REPO_HOST:-'proj.photobox.co.uk'}
BASE_REPO_PATH=${BASE_REPO_PATH:-'/install/repo/apt'}
REPO_INJECT_COMMAND=${REPO_INJECT_COMMAND:-'/handsfree/scripts/debrepo_simple.pl'}

for release in $UBUNTU_RELEASES; do
  REPO_PATH="${BASE_REPO_PATH}/${release}"
  scp *.deb $REPO_HOST:$REPO_PATH/binary
  [ "${release}" == "lucid" ] && ssh -n $REPO_HOST /handsfree/scripts/purge_debs.pl -v
  ssh -n $REPO_HOST $REPO_INJECT_COMMAND -r $REPO_PATH -d binary
done

set +x
echo ""
echo "============================================================"
echo "Build, packaging and repo injection of:"
echo ""
echo "${PACKAGE_NAME} ${PACKAGE_VERSION}"
if [ -f $PAYLOAD_DIR/build.info ]; then
  echo ""
  echo "Built against:"
  echo ""
  while read i; do
    echo $i
  done < $PAYLOAD_DIR/build.info
  echo ""
fi
echo "Complete."
echo "============================================================"
echo ""

set -x
rm *.deb
cd ..
rmdir $TMPDIR
