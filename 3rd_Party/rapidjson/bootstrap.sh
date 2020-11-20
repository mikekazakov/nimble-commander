#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/rapidjson.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b master --single-branch https://github.com/Tencent/rapidjson

cd ..

rm -rf ./include/

cp -R ${TMP_DIR}/rapidjson/include .

rm -rf ${TMP_DIR}
