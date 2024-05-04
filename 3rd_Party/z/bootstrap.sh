#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/libz.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

VER=1.3.1

wget https://zlib.net/zlib-${VER}.tar.gz
gunzip -c zlib-${VER}.tar.gz | tar xopf -

cd zlib-${VER}
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

cp ${TMP_DIR}/zlib-${VER}/build/libz.a ./lib/
cp ${TMP_DIR}/zlib-${VER}/build/zconf.h ./include/
cp ${TMP_DIR}/zlib-${VER}/zlib.h ./include/

rm -rf ${TMP_DIR} 
