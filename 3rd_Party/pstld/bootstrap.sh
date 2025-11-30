#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/pstld.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone https://github.com/mikekazakov/pstld

cd pstld

mkdir build
cd build

cmake \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
  -D CMAKE_CXX_FLAGS="-fvisibility=hidden -flto -Os" \
  ..
make -j

cd ./../../../
rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir include/pstld
mkdir lib

cp ./pstld.tmp/pstld/pstld/*.h ./include/pstld/
cp ./pstld.tmp/pstld/build/libpstld.a ./lib/

rm -rf ${TMP_DIR} 
