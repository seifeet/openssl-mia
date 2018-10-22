#!/bin/bash -e
# @author AT
# Hints and tips from:
# http://stackoverflow.com/questions/11929773/compiling-the-latest-openssl-for-android

if [ "$#" -ne 1 ]
then
    echo "Usage:"
    echo "./openssl-build <ANDROID_TARGET_ABI> "
    echo
    echo
    echo "Supported target ABIs: all, armeabi, armeabi-v7a, x86, x86_64, arm64-v8a"
    echo
    exit 1
fi

TARGET_ABI_LIST=$1

if [ "${TARGET_ABI_LIST}" = all ] ; then
  TARGET_ABI_LIST="armeabi armeabi-v7a x86 x86_64 arm64-v8a"
fi

# using
# NDK 16b
# GCC 4.9 (NDK_DIR/toolchains)
# OpenSSL 1.0.2o
# Android API 23 (NDK_DIR/platforms)
#

NDK_DIR=~/Projects/android/android-ndk-r17c

OPENSSL_TARGET_API=23
OPENSSL_GCC_VERSION=4.9

# 1.0.2e
# 1.0.2o
# 1.1.0h
# 1.1.0i
# 1.1.1
OPENSSL_VERSION=1.1.1
OPENSSL_VERSION_NUM=${OPENSSL_VERSION:0:5}
OPENSSL_NAME="openssl-${OPENSSL_VERSION}"
OPENSSL_FILE="${OPENSSL_NAME}.tar.gz"
OPENSSL_URL="https://www.openssl.org/source/${OPENSSL_FILE}"

BASE_DIR=`pwd`
BUILD_DIR="${BASE_DIR}/build"
FILES_DIR="${BUILD_DIR}/files"
LOG_DIR="${BUILD_DIR}/log"
OPENSSL_PATH="${FILES_DIR}/${OPENSSL_FILE}"

source ${BASE_DIR}/shared/utils.sh

if [[ ${OPENSSL_VERSION_NUM} < 1.1.1 ]]; then
  source ${BASE_DIR}/android/build-me-1.sh
else
  source ${BASE_DIR}/android/build-me-2.sh
fi

set -o xtrace
for TARGET_ABI in ${TARGET_ABI_LIST}; do
  DIST_DIR="${BUILD_DIR}/dist/android/${OPENSSL_NAME}/${TARGET_ABI}"
  SRC_DIR="${FILES_DIR}/android-${TARGET_ABI}"
  LOG_FILE="${LOG_DIR}/android-${OPENSSL_NAME}-${TARGET_ABI}.log"

  build_library
done
set +o xtrace
