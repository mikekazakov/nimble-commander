#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/json.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v3.11.3 --single-branch --depth 1 https://github.com/nlohmann/json.git

cd ..

rm -rf ./include/

mkdir include
mkdir include/nlohmann

cp ${TMP_DIR}/json/single_include/nlohmann/json.hpp ./include/nlohmann

rm -rf ${TMP_DIR}
