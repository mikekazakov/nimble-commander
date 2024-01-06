#!/bin/sh

set -e
set -o pipefail

if ! [ -x "$(command -v xcpretty)" ] ; then
    echo 'xcpretty is not found, aborting. (https://github.com/xcpretty/xcpretty)'
    exit -1
fi

# https://github.com/xcpretty/xcpretty/issues/48
export LC_CTYPE=en_US.UTF-8

# get current directory
SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# allocate a temp dir for build artifacts
BUILD_DIR=$(mktemp -d ${SCRIPTS_DIR}/build.XXXXXXXXX)

ROOT_DIR=$(cd "$SCRIPTS_DIR/.." && pwd)

LOG_FILE=${BUILD_DIR}/xcodebuild.log

if type -p /usr/local/bin/ccache >/dev/null 2>&1; then
    export CCACHE_BASEDIR="${ROOT_DIR}"
    export CCACHE_SLOPPINESS=time_macros,include_file_mtime,include_file_ctime,file_stat_matches
    export CC="${SCRIPTS_DIR}/ccache-clang"
    export CXX="${SCRIPTS_DIR}/ccache-clang++"
fi

build_target()
{
    TARGET=$1
    CONFIGURATION=$2
    echo building ${TARGET} - ${CONFIGURATION}
    XC="xcodebuild \
        -project ../Source/NimbleCommander/NimbleCommander.xcodeproj \
        -scheme ${TARGET} \
        -configuration ${CONFIGURATION} \
        SYMROOT=${BUILD_DIR} \
        OBJROOT=${BUILD_DIR} \
        -parallelizeTargets \
        OTHER_CFLAGS=\"-fdebug-prefix-map=${ROOT_DIR}=.\""
    BINARY_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//')
    BINARY_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//')
    BINARY_PATH=$BINARY_DIR/$BINARY_NAME
    $XC build | tee -a ${LOG_FILE} | xcpretty
}

# list of targets to build
tests=(\
BaseUT \
ConfigUT \
UtilityUT \
VFSIconUT \
VFSUT \
OperationsUT \
ViewerUT \
TermUT \
PanelUT \
NimbleCommanderUT \
)

# list of configurations to build the targets with
configurations=(\
Debug \
Release \
)

# run N * M binaries
for configuration in ${configurations[@]}; do
  for test in ${tests[@]}; do
    # build the binary
    build_target $test $configuration
    
    # execute the binary
    $BINARY_PATH
  done
done

# cleanup
rm -rf ${BUILD_DIR}
