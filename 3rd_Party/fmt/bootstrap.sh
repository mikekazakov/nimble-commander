#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/fmt.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b 11.0.2 --single-branch --depth=1 https://github.com/fmtlib/fmt.git

cd fmt
mkdir build
cd build

cmake \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_CXX_FLAGS="-fvisibility=hidden -flto" \
  -D CMAKE_CXX_STANDARD="23" \
  -D BUILD_SHARED_LIBS="OFF" \
  ..
make -j
make test

cd ./../../..
rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir lib

cp -r ./fmt.tmp/fmt/include/fmt ./include/
cp ./fmt.tmp/fmt/build/libfmt.a ./lib/

rm -rf ${TMP_DIR} 

exit 0
