#!/bin/sh
set -o pipefail
set -o xtrace

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/catch2.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v2.13.3 --single-branch https://github.com/catchorg/Catch2

cd ..

rm -rf ./include/

mkdir include
cp -R ${TMP_DIR}/Catch2/single_include/ ./include

rm -rf ${TMP_DIR}
