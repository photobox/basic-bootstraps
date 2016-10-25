#!/usr/bin/env bash
set -e

# Set to either "true" or "false" using a jenkins checkbox (boolean param)
if ! "$MAKE_PACKAGE"; then
  echo 'Not building package because $MAKE_PACKAGE is false'
  exit 0
fi

function bail {
    echo $1;
    exit 1;
}

[ -n "${PACKAGE_NAME}" ]   || bail '$PACKAGE_NAME unset'
[ -n "${PAYLOAD_DIR}" ]    || bail '$PAYLOAD_DIR unset'
[ -n "${BUILD_NUMBER}" ]   || bail 'Jenkins envvar $BUILD_NUMBER unset'
[ -n "${WORKSPACE}" ]      || bail 'Jenkins envvar $WORKSPACE unset'

SCRIPTS_DIR=${SCRIPTS_DIR:-'package-scripts'}
[[ $PAYLOAD_DIR =~ ^/ ]] || PAYLOAD_DIR="${WORKSPACE}/${PAYLOAD_DIR}"
[[ $SCRIPTS_DIR =~ ^/ ]] || SCRIPTS_DIR="${WORKSPACE}/${SCRIPTS_DIR}"

PACKAGE_VERSION="${VERSION:+${VERSION}-}${BUILD_NUMBER}-$(date -u +'%Y%m%d%H%M%S')"

INSTALL_PREFIX=${INSTALL_PREFIX:+"--prefix $INSTALL_PREFIX"}
TYPE='deb'
SOURCE='dir'
EMAIL='Photobox Babel Team <babelteam@photobox.com>'
URL='http://www.photobox.com'
VENDOR='PhotoBox'
DESCRIPTION='Boilerplate - please set $DESCRIPTION in control.sh
Boilerplate long description'

TMPDIR=$(mktemp -p . -d deb.XXXXXXXXXX)
cd $TMPDIR

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
set -x
fpm --verbose -C $PAYLOAD_DIR -t $TYPE -s $SOURCE -n $PACKAGE_NAME -v $PACKAGE_VERSION $INSTALL_PREFIX $DEPENDS_AS_OPTS $CONFLICTS_AS_OPTS $RECOMMENDS_AS_OPTS $SCRIPTS --description "$DESCRIPTION" -m "$EMAIL" --vendor $VENDOR --url $URL $FPM_EXTRA_FLAGS .
#PACKAGE_FILENAME=$(fpm --verbose -C $PAYLOAD_DIR -t $TYPE -s $SOURCE -n $PACKAGE_NAME -v $PACKAGE_VERSION $INSTALL_PREFIX $DEPENDS_AS_OPTS $CONFLICTS_AS_OPTS $RECOMMENDS_AS_OPTS $SCRIPTS --description "$DESCRIPTION" -m "$EMAIL" --vendor $VENDOR --url $URL $FPM_EXTRA_FLAGS .|ruby -e 'print (eval STDIN.readlines.last)[:path]')
set +x
PACKAGE_STAGING_DIR="${PACKAGE_STAGING_DIR:-/var/lib/jenkins/package_staging}"
PROPERTIES_FILE="${WORKSPACE}/${PROPERTIES_FILE:-package.properties}"
echo "Staging for injection to S3 repo '${S3_BUCKET}'"
mv ${PACKAGE_FILENAME} ${PACKAGE_STAGING_DIR}
echo "STAGED_PACKAGE_FILENAME=${PACKAGE_STAGING_DIR}/${PACKAGE_FILENAME}" > ${PROPERTIES_FILE}

set +x
echo
echo "============================================================"
echo "Build, packaging and repo injection of:"
echo ""
echo "${PACKAGE_NAME} ${PACKAGE_VERSION}"
echo ""
if [ -f $PAYLOAD_DIR/build.info ]; then
  echo "Built against:"
  echo ""
  while read i; do
    echo $i
  done < $PAYLOAD_DIR/build.info
  echo ""
fi
echo "Complete."
echo "============================================================"
echo
set -x

cd ..
rmdir $TMPDIR
