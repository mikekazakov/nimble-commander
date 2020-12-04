#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/rh.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b 3.9.1 --single-branch https://github.com/martinus/robin-hood-hashing.git

cd ..

rm -rf ./include/

mkdir include
cp ${TMP_DIR}/robin-hood-hashing/src/include/robin_hood.h ./include

rm -rf ${TMP_DIR}
