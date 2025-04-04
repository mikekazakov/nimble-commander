#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/magic_enum.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v0.9.7 --single-branch https://github.com/Neargye/magic_enum

cd ..

rm -rf ./include/

mkdir include
cp ${TMP_DIR}/magic_enum/include/magic_enum/*.hpp ./include

rm -rf ${TMP_DIR}
