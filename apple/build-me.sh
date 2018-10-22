#!/bin/bash

###############################################################################
##                                                                           ##
## Build and package OpenSSL static libraries for OSX/iOS                    ##
##                                                                           ##
## This script is in the public domain.                                      ##
## Creator     : Laurent Etiemble                                            ##
##                                                                           ##
###############################################################################

## --------------------
## Settings
## --------------------

# 1.0.2e
# 1.0.2o
# 1.1.0h
# 1.1.0i
# 1.1.1
OPENSSL_VERSION=1.1.1
OSX_SDK=10.14
MIN_OSX=10.6
IOS_SDK=12.0

BUILD_iOS=true
BUILD_MacOS=true
CREATE_TAR_FILE=true

# These values are used to avoid version detection
FAKE_NIBBLE=0x102031af
FAKE_TEXT="OpenSSL 0.9.8y 5 Feb 2013"

iOS_ARCHS="i386 x86_64 armv7 armv7s arm64"
# armv7 & armv7s can be neglected at this point
# less than 0.1% of devices have iOS < 7
# iOS_ARCHS="i386 x86_64 armv7 armv7s arm64"
MacOS_ARCHS="i386 x86_64"

## --------------------
## Variables
## --------------------

DEVELOPER_DIR=`xcode-select -print-path`
if [ ! -d ${DEVELOPER_DIR} ]; then
    echo "Please set up Xcode correctly. '${DEVELOPER_DIR}' is not a valid developer tools folder."
    exit 1
fi
if [ ! -d "${DEVELOPER_DIR}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${OSX_SDK}.sdk" ]; then
    echo "The OS X SDK ${OSX_SDK} was not found."
    exit 1
fi
if [ ! -d "${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${IOS_SDK}.sdk" ]; then
    echo "The iOS SDK ${IOS_SDK} was not found."
    exit 1
fi

OPENSSL_VERSION_NUM=${OPENSSL_VERSION:0:5}
OPENSSL_NAME="openssl-${OPENSSL_VERSION}"
OPENSSL_FILE="${OPENSSL_NAME}.tar.gz"
OPENSSL_URL="https://www.openssl.org/source/${OPENSSL_FILE}"

BASE_DIR=`pwd`
BUILD_DIR="${BASE_DIR}/build"
DIST_DIR="${BUILD_DIR}/dist/apple/${OPENSSL_NAME}"
FILES_DIR="${BUILD_DIR}/files"
LOG_DIR="${BUILD_DIR}/log"
OPENSSL_PATH="${FILES_DIR}/${OPENSSL_FILE}"

## --------------------
## Main
## --------------------

source ${BASE_DIR}/shared/utils.sh
source ${BASE_DIR}/apple/build-me-mac-os.sh

vercomp ${OPENSSL_VERSION} "1.1.1"
case $? in
    # >=
    0 | 1)
      echo "Building for OpenSSL >= 1.1.1"
      source ${BASE_DIR}/apple/build-me-ios-1-1-1.sh
      ;;
    # <
    2)
      echo "Building for OpenSSL < 1.1.1"
      source ${BASE_DIR}/apple/build-me-ios.sh
      ;;
    *) ;;
esac

# print each command before executing
set -o xtrace

if [ "$BUILD_iOS" = true ] ; then
  build_ios
  distribute_ios
fi

if [ "$BUILD_MacOS" = true ] ; then
  build_osx
  distribute_osx
fi

set +o xtrace
