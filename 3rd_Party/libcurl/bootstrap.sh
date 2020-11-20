#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR="$(dirname "$0")"
TMP_DIR=${CUR_DIR}/curl.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone https://github.com/curl/curl.git
cd curl

./buildconf
export MACOSX_DEPLOYMENT_TARGET="10.11"
./configure --disable-shared --enable-static --disable-ldap --without-libidn2 --with-darwinssl 
make

cd ./../../
rm -rf ./include/
rm -rf ./built/

mkdir include
mkdir include/curl
mkdir built
cp ./curl.tmp/curl/include/curl/*.h ./include/curl/
cp ./curl.tmp/curl/lib/.libs/libcurl.a ./built/

rm -rf ${TMP_DIR} 
