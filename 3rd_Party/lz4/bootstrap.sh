#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/lz4.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v1.10.0 --single-branch https://github.com/lz4/lz4.git

cd lz4/build/cmake
mkdir builddir
cd builddir

cmake \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_C_FLAGS="-fvisibility=hidden -flto -DLZ4LIB_VISIBILITY=" \
  -D BUILD_SHARED_LIBS="OFF" \
  -D BUILD_STATIC_LIBS="ON" \
  ..
make -j

cd ./../../../../../
rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir lib

cp ./lz4.tmp/lz4/lib/lz4*.h ./include/
cp ./lz4.tmp/lz4/build/cmake/builddir/liblz4.a ./lib/

rm -rf ${TMP_DIR} 
