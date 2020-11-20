#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/libz.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

wget https://zlib.net/zlib-1.2.11.tar.gz 
gunzip -c zlib-1.2.11.tar.gz | tar xopf -

cd zlib-1.2.11
mkdir build && cd build
cmake .. && make -j zlibstatic

cd ../../..

rm -rf ./include/
rm -rf ./built/
mkdir include
mkdir built

cp ${TMP_DIR}/zlib-1.2.11/build/libz.a ./built/
cp ${TMP_DIR}/zlib-1.2.11/build/zconf.h ./include/
cp ${TMP_DIR}/zlib-1.2.11/zlib.h ./include/

rm -rf ${TMP_DIR} 
