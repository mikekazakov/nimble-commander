#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/zstd.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v1.5.6 --single-branch https://github.com/facebook/zstd.git

cd zstd/build/cmake
mkdir builddir
cd builddir

cmake \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_C_FLAGS="-fvisibility=hidden -flto -DZSTDLIB_VISIBLE= -DZSTDLIB_HIDDEN=" \
  -D BUILD_SHARED_LIBS="OFF" \
  -D ZSTD_BUILD_STATIC="ON" \
  -D ZSTD_BUILD_SHARED="OFF" \
  ..
make -j

cd ./../../../../../
rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir lib

cp ./zstd.tmp/zstd/lib/*.h ./include/
cp ./zstd.tmp/zstd/build/cmake/builddir/lib/libzstd.a ./lib/

rm -rf ${TMP_DIR} 
