#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/libssh2.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b libssh2-1.9.0 --single-branch https://github.com/libssh2/libssh2.git
cd libssh2

./buildconf
export MACOSX_DEPLOYMENT_TARGET="10.11"

./configure \
--disable-shared \
--enable-static \
--enable-crypt-none \
--enable-mac-none \
--with-libssl-prefix=${CUR_DIR}/../OpenSSL/ \
--with-libz \
CFLAGS='-g -O3'

make

cd ./../../
rm -rf ./include/
rm -rf ./built/

mkdir include
mkdir built
cp ${TMP_DIR}/libssh2/include/*.h ./include/
cp ${TMP_DIR}/libssh2/src/.libs/libssh2.a ./built/

rm -rf ${TMP_DIR} 
