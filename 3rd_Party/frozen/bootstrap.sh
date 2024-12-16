#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/frozen.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b 1.2.0 --single-branch https://github.com/serge-sans-paille/frozen

cd ..

rm -rf ./include/

mkdir include
cp -R ${TMP_DIR}/frozen/include/ ./include
rm -f ./include/frozen/CMakeLists.txt

rm -rf ${TMP_DIR}


