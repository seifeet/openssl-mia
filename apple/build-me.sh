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
# 1.1.1-pre8
OPENSSL_VERSION=1.1.0i
OSX_SDK=10.13
MIN_OSX=10.6
IOS_SDK=11.4

BUILD_iOS=true
BUILD_MacOS=false
CREATE_TAR_FILE=true

# These values are used to avoid version detection
FAKE_NIBBLE=0x102031af
FAKE_TEXT="OpenSSL 0.9.8y 5 Feb 2013"

# iOS_ARCHS="arm64"
# armv7 & armv7s can be neglected at this point
# less than 0.1% of devices have iOS < 7
iOS_ARCHS="i386 x86_64 armv7 armv7s arm64"
MacOS_ARCHS="i386"

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
_configure() {
	# Configure
	if [ "x${DONT_CONFIGURE}" == "x" ]; then
		echo "Configuring ${PLATFORM}-${ARCH}..."
    CONFIGURE_OPTIONS=""
    vercomp ${OPENSSL_VERSION} "1.1"
    case $? in
        # <
        2) CONFIGURE_OPTIONS="no-app";;
        *) ;;
    esac
		(cd "${SRC_DIR}"; CROSS_TOP="${CROSS_TOP}" CROSS_SDK="${CROSS_SDK}" CC="${CC}" ./Configure ${COMPILER} ${CONFIGURE_OPTIONS} --openssldir="${DST_DIR}" --prefix="${DST_DIR}" > "${LOG_FILE}" 2>&1)
	fi
}

_build() {
	# Build
	if [ "x${DONT_BUILD}" == "x" ]; then
		echo "Building ${PLATFORM}-${ARCH}..."
		(cd "${SRC_DIR}"; CROSS_TOP="${CROSS_TOP}" CROSS_SDK="${CROSS_SDK}" CC="${CC}" make >> "${LOG_FILE}" 2>&1)
	fi
}

build_osx() {
	for ARCH in ${MacOS_ARCHS}; do
		PLATFORM="MacOSX"
		COMPILER="darwin-i386-cc"
		SRC_DIR="${FILES_DIR}/${PLATFORM}-${ARCH}"
		DST_DIR="${DIST_DIR}/${PLATFORM}-${ARCH}"
		LOG_FILE="${LOG_DIR}/${PLATFORM}${OSX_SDK}-${ARCH}.log"

		# Select the compiler
		if [ "${ARCH}" == "i386" ]; then
			COMPILER="darwin-i386-cc"
		else
			COMPILER="darwin64-x86_64-cc"
		fi

		CROSS_TOP="${DEVELOPER_DIR}/Platforms/${PLATFORM}.platform/Developer"
		CROSS_SDK="${PLATFORM}${OSX_SDK}.sdk"
		CC="${DEVELOPER_DIR}/usr/bin/gcc -arch ${ARCH}"

    file_setup
		unarchive
		_configure

		# Patch Makefile
		sed -i'.bak' "s/^CFLAG= -/CFLAG=  -mmacosx-version-min=${MIN_OSX} -/" "${SRC_DIR}/Makefile"
		# Patch versions
    # some headers have moved starting 1.1
    if [[ ${OPENSSL_VERSION:0:3} < 1.1 ]]; then
      sed -i'.bak' "s/^# define OPENSSL_VERSION_NUMBER.*$/# define OPENSSL_VERSION_NUMBER  $FAKE_NIBBLE/" "${SRC_DIR}/crypto/opensslv.h"
  		sed -i'.bak' "s/^#  define OPENSSL_VERSION_TEXT.*$/#  define OPENSSL_VERSION_TEXT  \"$FAKE_TEXT\"/" "${SRC_DIR}/crypto/opensslv.h"
    else
      sed -i'.bak' "s/^# define OPENSSL_VERSION_NUMBER.*$/# define OPENSSL_VERSION_NUMBER  $FAKE_NIBBLE/" "${SRC_DIR}/include/openssl/opensslv.h"
  		sed -i'.bak' "s/^#  define OPENSSL_VERSION_TEXT.*$/#  define OPENSSL_VERSION_TEXT  \"$FAKE_TEXT\"/" "${SRC_DIR}/include/openssl/opensslv.h"
    fi

		_build
	done
}

distribute_osx() {
	PLATFORM="MacOSX"
	NAME="${OPENSSL_NAME}-${PLATFORM}"
	DST_DIR="${DIST_DIR}/${PLATFORM}"
	FILES="libcrypto.a libssl.a"

  if [ -d "${DST_DIR}" ]; then
    echo "Remove folder ${DST_DIR}..."
    rm -rf ${DST_DIR};
  fi

	mkdir -p "${DST_DIR}/include"
	mkdir -p "${DST_DIR}/lib"

	echo "${OPENSSL_VERSION}" > "${DST_DIR}/VERSION"

  for ARCH in ${MacOS_ARCHS}; do
    cp "${FILES_DIR}/MacOSX-${ARCH}/LICENSE" "${DST_DIR}"
    cp -LR "${FILES_DIR}/MacOSX-${ARCH}/include/" "${DST_DIR}/include"
    # use the first ARCH for include
    break
  done

	# Alter rsa.h to make Swift happy
	sed -i'.bak' 's/const BIGNUM \*I/const BIGNUM *i/g' "${DST_DIR}/include/openssl/rsa.h"

  for f in ${FILES}; do
    LIPO_CREATE=""
    for ARCH in ${MacOS_ARCHS}; do
      LIPO_CREATE=$LIPO_CREATE" ${FILES_DIR}/MacOSX-${ARCH}/$f"
    done
    lipo -create $LIPO_CREATE -output "${DST_DIR}/lib/$f"
  done

  if [ "$CREATE_TAR_FILE" = true ] ; then
      (cd "${DIST_DIR}"; tar -cvf "${NAME}.tar.gz" "${PLATFORM}")
  fi
}

build_ios() {
	for ARCH in $iOS_ARCHS; do
		PLATFORM="iPhoneOS"
		SRC_DIR="${FILES_DIR}/${PLATFORM}-${ARCH}"
		DST_DIR="${DIST_DIR}/${PLATFORM}-${ARCH}"
		LOG_FILE="${LOG_DIR}/${PLATFORM}${IOS_SDK}-${ARCH}.log"

    COMPILER="iphoneos-cross"
    CC_FLAGS="-arch ${ARCH}"

		# Select the compiler
		if [ "${ARCH}" == "i386" ]; then
			PLATFORM="iPhoneSimulator"
			MIN_IOS="4.2"
		elif [ "${ARCH}" == "x86_64" ]; then
			PLATFORM="iPhoneSimulator"
			MIN_IOS="7.0"
		elif [ "${ARCH}" == "arm64" ]; then
			MIN_IOS="7.0"
      vercomp ${OPENSSL_VERSION} "1.0.2"
      case $? in
          # >
          1)
            COMPILER="ios64-cross"
            CC_FLAGS=""
            ;;
          *) ;;
      esac
    elif [ "${ARCH}" == "armv7" ]; then
      MIN_IOS="6.0"
      vercomp ${OPENSSL_VERSION} "1.0.2"
      case $? in
          # >
          1)
            COMPILER="ios-cross"
            CC_FLAGS=""
            ;;
          *) ;;
      esac
    elif [ "${ARCH}" == "armv7s" ]; then
      MIN_IOS="6.0"
      vercomp ${OPENSSL_VERSION} "1.0.2"
		else
			echo "ERROR: Unsupported architecture!"
		fi

    # looks like a bug in 1.1.1-pre8 build scripts
    # -Wa, is not supported with -fembed-bitcode
    vercomp ${OPENSSL_VERSION} "1.1.1"
    case $? in
        # <
        2)
          CC_FLAGS=${CC_FLAGS}" -fembed-bitcode"
          ;;
        *) ;;
    esac

		CROSS_TOP="${DEVELOPER_DIR}/Platforms/${PLATFORM}.platform/Developer"
		CROSS_SDK="${PLATFORM}${IOS_SDK}.sdk"
    CC="clang ${CC_FLAGS}"

    file_setup
		unarchive
		_configure

		# Patch Makefile
    if [ "${ARCH}" == "x86_64" ]; then
			sed -i'.bak' "s/^CFLAG= -/CFLAG=  -miphoneos-version-min=$MIN_IOS -DOPENSSL_NO_ASM -/" "${SRC_DIR}/Makefile"
    else
			sed -i'.bak' "s/^CFLAG= -/CFLAG=  -miphoneos-version-min=$MIN_IOS -/" "${SRC_DIR}/Makefile"
    fi
    # Patch versions
    # some headers have moved starting 1.1
    if [[ ${OPENSSL_VERSION:0:3} < 1.1 ]]; then
      sed -i'.bak' "s/^# define OPENSSL_VERSION_NUMBER.*$/# define OPENSSL_VERSION_NUMBER  $FAKE_NIBBLE/" "${SRC_DIR}/crypto/opensslv.h"
      sed -i'.bak' "s/^#  define OPENSSL_VERSION_TEXT.*$/#  define OPENSSL_VERSION_TEXT  \"$FAKE_TEXT\"/" "${SRC_DIR}/crypto/opensslv.h"
    else
      sed -i'.bak' "s/^# define OPENSSL_VERSION_NUMBER.*$/# define OPENSSL_VERSION_NUMBER  $FAKE_NIBBLE/" "${SRC_DIR}/include/openssl/opensslv.h"
      sed -i'.bak' "s/^#  define OPENSSL_VERSION_TEXT.*$/#  define OPENSSL_VERSION_TEXT  \"$FAKE_TEXT\"/" "${SRC_DIR}/include/openssl/opensslv.h"
    fi

		_build
	done
}

distribute_ios() {
	PLATFORM="iOS"
	NAME="${OPENSSL_NAME}-${PLATFORM}"
	DST_DIR="${DIST_DIR}/${PLATFORM}"
	FILES="libcrypto.a libssl.a"

  if [ -d "${DST_DIR}" ]; then
    echo "Remove folder ${DST_DIR}..."
    rm -rf ${DST_DIR};
  fi

	mkdir -p "${DST_DIR}/include"
	mkdir -p "${DST_DIR}/lib"

	echo "${OPENSSL_VERSION}" > "${DST_DIR}/VERSION"

  for ARCH in $iOS_ARCHS; do
    cp "${FILES_DIR}/iPhoneOS-${ARCH}/LICENSE" "${DST_DIR}"
    cp -LR "${FILES_DIR}/iPhoneOS-${ARCH}/include/" "${DST_DIR}/include"
    # use the first ARCH for include
    break
  done

	# Alter rsa.h to make Swift happy
	sed -i'.bak' 's/const BIGNUM \*I/const BIGNUM *i/g' "${DST_DIR}/include/openssl/rsa.h"

	for f in ${FILES}; do
    LIPO_CREATE=""
    for ARCH in $iOS_ARCHS; do
			LIPO_CREATE=$LIPO_CREATE" ${FILES_DIR}/iPhoneOS-${ARCH}/$f"
    done
		lipo -create $LIPO_CREATE -output "${DST_DIR}/lib/$f"
	done

  if [ "$CREATE_TAR_FILE" = true ] ; then
      (cd "${DIST_DIR}"; tar -cvf "${NAME}.tar.gz" "${PLATFORM}")
  fi
}

source ${BASE_DIR}/shared/utils.sh

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
