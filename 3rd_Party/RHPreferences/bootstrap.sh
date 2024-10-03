#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/RHPreferences.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone --single-branch --depth=1 https://github.com/heardrwt/RHPreferences.git
cd RHPreferences

clang++ -c \
  -arch arm64 -arch x86_64 \
  -fvisibility=hidden \
  -flto \
  -Os \
  -mmacosx-version-min=10.15 \
  -DNDEBUG \
  -ObjC \
  RHPreferences/RHPreferencesWindowController.m

libtool -static -o libRHPreferences.a RHPreferencesWindowController.o

cd ./../../
rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir include/RHPreferences
mkdir lib
cp ${TMP_DIR}/RHPreferences/RHPreferences/*.h ./include/RHPreferences
cp ${TMP_DIR}/RHPreferences/libRHPreferences.a ./lib/
cp ${TMP_DIR}/RHPreferences/RHPreferences/RHPreferencesWindow.xib ./lib/

rm -rf ${TMP_DIR}
