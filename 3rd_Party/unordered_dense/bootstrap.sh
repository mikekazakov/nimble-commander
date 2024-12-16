#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/ud.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v4.5.0 --single-branch https://github.com/martinus/unordered_dense.git

cd ..

rm -rf ./include/

mkdir include
cp -r ${TMP_DIR}/unordered_dense/include/ankerl ./include

rm -rf ${TMP_DIR}
