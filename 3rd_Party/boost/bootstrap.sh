#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/boost.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

wget https://boostorg.jfrog.io/artifactory/main/release/1.83.0/source/boost_1_83_0.tar.gz
tar -xf boost_1_83_0.tar.gz
cd boost_1_83_0
./bootstrap.sh --with-libraries=filesystem,system,container

CFLAGS="-Os -fvisibility=hidden -fvisibility-inlines-hidden -mmacosx-version-min=10.15 -arch x86_64 -arch arm64 -isysroot $(xcrun --sdk macosx --show-sdk-path)"

./b2 \
  cflags="${CFLAGS}" \
  cxxflags="${CFLAGS} -std=c++20" \
  link=static \
  lto=on
 
cd ../..

rm -rf ./include/
rm -rf ./lib/
mkdir include
mkdir lib

cp -R ${TMP_DIR}/boost_1_83_0/boost ./include/
cp ${TMP_DIR}/boost_1_83_0/stage/lib/*.a ./lib/

rm -rf ${TMP_DIR}
