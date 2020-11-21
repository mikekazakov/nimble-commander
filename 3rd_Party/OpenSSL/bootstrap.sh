#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/openssl.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR}

git clone -b OpenSSL_1_1_1 --single-branch https://github.com/openssl/openssl.git
cd openssl
./config \
  --with-zlib-include=../../../z/include \
  --with-zlib-lib=../../../z/built \
  --prefix=${CUR_DIR}/openssl.tmp/installed/ \
  no-shared \
  zlib \
  enable-md2 \
  enable-rc5
make -j
make test
make install

cd ../..

rm -rf ./include/
rm -rf ./built/
mkdir include
mkdir built

cp ${TMP_DIR}/installed/lib/*.a ./built/
cp -R ${TMP_DIR}/installed/include/* ./include/

rm -rf ${TMP_DIR}
