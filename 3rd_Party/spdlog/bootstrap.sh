#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/spdlog.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v1.15.0 --single-branch --depth=1 https://github.com/gabime/spdlog.git
cd spdlog

clang++ -c \
  -arch arm64 -arch x86_64 \
  -std=c++2b \
  -fvisibility=hidden \
  -flto \
  -Os \
  -mmacosx-version-min=10.15 \
  -DNDEBUG \
  -DSPDLOG_COMPILED_LIB \
  -DSPDLOG_FMT_EXTERNAL \
  -I./include \
  -I./../../../fmt/include \
  src/async.cpp src/cfg.cpp src/color_sinks.cpp src/file_sinks.cpp src/spdlog.cpp src/stdout_sinks.cpp

libtool -static -o libspdlog.a async.o cfg.o color_sinks.o file_sinks.o spdlog.o stdout_sinks.o

cd ./../../
rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir lib
cp -R ${TMP_DIR}/spdlog/include/spdlog ./include/
cp ${TMP_DIR}/spdlog/libspdlog.a ./lib/

rm  -f ./include/spdlog/cfg/*-inl.h
rm  -f ./include/spdlog/details/*-inl.h
rm -rf ./include/spdlog/fmt/bundled
rm  -f ./include/spdlog/sinks/*-inl.h
rm  -f ./include/spdlog/*-inl.h
rm -rf ${TMP_DIR}

