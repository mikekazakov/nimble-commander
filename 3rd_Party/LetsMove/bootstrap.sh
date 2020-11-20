#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/rapidjson.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v1.25 --single-branch https://github.com/potionfactory/LetsMove.git

cd LetsMove

XC="xcodebuild \
  -project LetsMove.xcodeproj \
  -scheme LetsMove \
  -configuration Release"
BINARY_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//')
BINARY_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//')
BINARY_PATH=$BINARY_DIR/$BINARY_NAME
echo ${BINARY_PATH}
$XC clean build

cd ./../..

rm -rf ./LetsMove.framework

cp -R ${BINARY_PATH} .

rm -rf ${TMP_DIR}
