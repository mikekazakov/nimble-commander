#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/expected.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v1.0.0 --single-branch https://github.com/TartanLlama/expected

cd ..

rm -rf ./include/

mkdir include
cp -R ${TMP_DIR}/expected/include/ ./include

rm -rf ${TMP_DIR}
