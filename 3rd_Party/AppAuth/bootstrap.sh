#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/appauth.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b 1.7.6 --single-branch --depth=1 https://github.com/openid/AppAuth-iOS.git

cd AppAuth-iOS

XC="xcodebuild \
  -project AppAuth.xcodeproj \
  -scheme AppAuth-macOS \
  -configuration Release"
BINARY_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//')
BINARY_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//')
BINARY_PATH=$BINARY_DIR/$BINARY_NAME
echo ${BINARY_PATH}
$XC clean build

cd ./../..

rm -rf ./include
rm -rf ./built

mkdir include
mkdir include/AppAuth
mkdir built

cp ${BINARY_PATH} ./built
cp ${TMP_DIR}/AppAuth-iOS/Sources/*.h ./include/AppAuth
cp ${TMP_DIR}/AppAuth-iOS/Sources/AppAuthCore/*.h ./include/AppAuth
cp ${TMP_DIR}/AppAuth-iOS/Sources/AppAuth/macOS/*.h ./include/AppAuth
cp ${TMP_DIR}/AppAuth-iOS/Sources/AppAuth/macOS/LoopbackHTTPServer/*.h ./include/AppAuth

rm -rf ${TMP_DIR}
