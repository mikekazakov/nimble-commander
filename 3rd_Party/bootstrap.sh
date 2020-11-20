#!/bin/sh
set -o pipefail
set -o xtrace

# pour yourself some coffee and relax, it'll take a while
export MACOSX_DEPLOYMENT_TARGET="10.15"
./z/bootstrap.sh
./bz2/bootstrap.sh
./spdlog/bootstrap.sh
