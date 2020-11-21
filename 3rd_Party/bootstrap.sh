#!/bin/sh
set -o pipefail
set -o xtrace
set -e

# pour yourself some coffee and relax, it'll take a while
export MACOSX_DEPLOYMENT_TARGET="10.15"
./z/bootstrap.sh
./bz2/bootstrap.sh
./lzma/bootstrap.sh
./openssl/bootstrap.sh
./curl/bootstrap.sh
./boost/bootstrap.sh
./spdlog/bootstrap.sh
