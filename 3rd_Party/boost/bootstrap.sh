#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/boost.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

wget https://dl.bintray.com/boostorg/release/1.74.0/source/boost_1_74_0.zip
unzip boost_1_74_0.zip
cd boost_1_74_0
./bootstrap.sh --with-libraries=filesystem,system

./b2 \
  cxxflags="-fvisibility=hidden -fvisibility-inlines-hidden -std=c++17 -mmacosx-version-min=10.15 -arch x86_64 -arch arm64" \
  link=static \
  lto=on
 
cd ../..

rm -rf ./include/
rm -rf ./lib/
mkdir include
mkdir lib

cp -R ${TMP_DIR}/boost_1_74_0/boost ./include/
cp ${TMP_DIR}/boost_1_74_0/stage/lib/*.a ./lib/

rm -rf ${TMP_DIR}
