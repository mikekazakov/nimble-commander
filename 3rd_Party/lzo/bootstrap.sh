#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/liblzo.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

wget http://www.oberhumer.com/opensource/lzo/download/lzo-2.10.tar.gz
gunzip -c lzo-2.10.tar.gz | tar xopf -

cd lzo-2.10

patch -p1 < ../../CMakeLists.txt.patch

mkdir build && cd build
cmake \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_C_FLAGS="-fvisibility=hidden -flto" \
  -D ENABLE_STATIC=ON \
  -D ENABLE_SHARED=OFF \
  ..
make -j

cd ../../..

rm -rf ./include/
rm -rf ./lib/
mkdir include
mkdir lib

cp ${TMP_DIR}/lzo-2.10/build/liblzo2.a ./lib/
cp -r ${TMP_DIR}/lzo-2.10/include/lzo ./include/

rm -rf ${TMP_DIR} 
