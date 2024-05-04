#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/pugixml.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v1.14 --single-branch --depth=1 https://github.com/zeux/pugixml.git
cd pugixml
mkdir build
cd build
cmake \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_CXX_FLAGS="-fvisibility=hidden -flto -Os" \
  ..
make -j
cd ../../..

rm -rf ./include/
rm -rf ./lib/
mkdir include
mkdir include/pugixml
mkdir lib

cp ./pugixml.tmp/pugixml/build/*.a ./lib/
cp ./pugixml.tmp/pugixml/src/*.hpp ./include/pugixml/

rm -rf ${TMP_DIR} 
