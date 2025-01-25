#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/lexilla.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR}

wget https://www.scintilla.org/scintilla554.zip
unzip scintilla554.zip

git clone -b rel-5-4-2 --single-branch --depth=1 https://github.com/ScintillaOrg/lexilla.git
cd lexilla

source_files=""
for file in $(find ./src -name "*.cxx"); do
    source_files="$source_files $file"
done
for file in $(find ./lexers -name "*.cxx"); do
    source_files="$source_files $file"
done
for file in $(find ./lexlib -name "*.cxx"); do
    source_files="$source_files $file"
done

echo $source_files

clang++ -c \
  -arch arm64 -arch x86_64 \
  -std=c++2b \
  -fvisibility=hidden \
  -flto \
  -Os \
  -mmacosx-version-min=10.15 \
  -DNDEBUG \
  -I./include \
  -I./lexlib \
  -I./../scintilla/include \
  $source_files

libtool -static -o liblexilla.a *.o

cd ./../..

rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir include/lexilla
mkdir include/scintilla
mkdir lib

cp ${TMP_DIR}/lexilla/include/*.h ./include/lexilla
cp ${TMP_DIR}/lexilla/lexlib/*.h ./include/lexilla
cp ${TMP_DIR}/scintilla/include/*.h ./include/scintilla
cp ${TMP_DIR}/lexilla/liblexilla.a ./lib/

rm -rf ${TMP_DIR}

./extract_names.sh ./include/lexilla/SciLexer.h > ./include/lexilla/SciLexerStyleNames.h
