#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/curl.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b curl-7_73_0 --single-branch https://github.com/curl/curl.git

cd curl

./buildconf
./configure \
  --disable-shared \
  --enable-static \
  --disable-ldap \
  --without-libidn2 \
  --with-secure-transport \
  --with-zlib=${CUR_DIR}/../z/include
make -j

cd ./../../
rm -rf ./include/
rm -rf ./built/

mkdir include
mkdir include/curl
mkdir built
cp ./curl.tmp/curl/include/curl/*.h ./include/curl/
cp ./curl.tmp/curl/lib/.libs/libcurl.a ./built/

rm -rf ${TMP_DIR} 
