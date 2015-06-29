#!/usr/bin/env bash
set -e

# Set to either "true" or "false" using a jenkins checkbox (boolean param)
if ! "$MAKE_PACKAGE"; then
  echo 'Not building package because $MAKE_PACKAGE is false'
  exit 0
fi

# TODO: find a better fix for this hack that works around Ubuntu not setting
# PATH up so gem executables work on Ubuntu 10.04
FPM=$(gem which fpm)
FPM="${FPM%/lib/fpm.rb}/bin/fpm"

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
PACKAGE_AS_ROOT=${PACKAGE_AS_ROOT:-false}
VERSION=${VERSION:-"1.2"}

# maintain behaviour whereby the current directory is assumed to be an SVN
# working copy if REVISION is not supplied. Also handle the case where REVISION
# isn't supplied and the current directory isn't an SVN working copy.
if [ -z "${REVISION}" ] && svn info $PAYLOAD_DIR >/dev/null 2>&1; then
  REVISION=$(svnversion $PAYLOAD_DIR | sed 's/^.*://')
fi
PACKAGE_VERSION="${VERSION}-${BUILD_NUMBER}-$(date -u +'%Y%m%d%H%M%S')${REVISION:+r$REVISION}"

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

"$PACKAGE_AS_ROOT" && SUDO="sudo"

PACKAGE_FILENAME=$($SUDO $FPM -C $PAYLOAD_DIR -t $TYPE -s $SOURCE -n $PACKAGE_NAME -v $PACKAGE_VERSION $INSTALL_PREFIX $DEPENDS_AS_OPTS $CONFLICTS_AS_OPTS $RECOMMENDS_AS_OPTS $SCRIPTS --description "$DESCRIPTION" -m "$EMAIL" --vendor $VENDOR --url $URL $FPM_EXTRA_FLAGS .|ruby -e 'print (eval STDIN.readlines.last)[:path]')

RELEASE_CODENAME=$(lsb_release -cs)
if dpkg --compare-versions "$(lsb_release -rs)" "<" "12.04"; then
  REPO_HOST=${REPO_HOST:-"proj.photobox.co.uk"}
  echo "Running on Ubuntu < 12.04, uploading to on-premise repo at '${REPO_HOST}'"
  BASE_REPO_PATH=${BASE_REPO_PATH:-"/install/repo/apt"}
  REPO_INJECT_COMMAND=${REPO_INJECT_COMMAND:-"/handsfree/scripts/debrepo_simple.pl"}

  REPO_PATH="${BASE_REPO_PATH}/${RELEASE_CODENAME}"
  scp $PACKAGE_FILENAME $REPO_HOST:$REPO_PATH/binary
  [ "${RELEASE_CODENAME}" == "lucid" ] && ssh -n $REPO_HOST /handsfree/scripts/purge_debs.pl -v
  ssh -n $REPO_HOST $REPO_INJECT_COMMAND -r $REPO_PATH -d binary
else
  S3_BUCKET=${S3_BUCKET:-"apt-photobox-babel"}
  echo "Running on Ubuntu >= 12.04, uploading direct to S3 bucket '${S3_BUCKET}'"
  RELEASE_CODENAME=$(lsb_release -cs)
  deb-s3 upload -p -b ${S3_BUCKET} -v authenticated -c ${RELEASE_CODENAME} ${PACKAGE_FILENAME}
fi

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

$SUDO rm ${PACKAGE_FILENAME}
cd ..
rmdir $TMPDIR
