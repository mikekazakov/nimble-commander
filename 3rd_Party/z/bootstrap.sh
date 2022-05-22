#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/libz.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

wget https://zlib.net/zlib-1.2.12.tar.gz
gunzip -c zlib-1.2.12.tar.gz | tar xopf -

cd zlib-1.2.12
mkdir build && cd build
cmake \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_C_FLAGS="-fvisibility=hidden -flto" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  ..
make -j zlibstatic

cd ../../..

rm -rf ./include/
rm -rf ./lib/
mkdir include
mkdir lib

cp ${TMP_DIR}/zlib-1.2.12/build/libz.a ./lib/
cp ${TMP_DIR}/zlib-1.2.12/build/zconf.h ./include/
cp ${TMP_DIR}/zlib-1.2.12/zlib.h ./include/

rm -rf ${TMP_DIR} 
