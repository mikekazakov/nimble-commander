#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/ctrail.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone https://github.com/mikekazakov/ctrail
cd ctrail

export MACOSX_DEPLOYMENT_TARGET="10.15"
clang++ -arch x86_64 -arch arm64 -fvisibility=hidden -flto -Os -std=c++17 -I./include ./src/CTrail-all.cpp -c
ar rcs libctrail.a CTrail-all.o

cd ./../../
rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir lib

cp -r ${TMP_DIR}/ctrail/include/ctrail ./include/
cp ${TMP_DIR}/ctrail/libctrail.a ./lib/

rm -rf ${TMP_DIR} 
