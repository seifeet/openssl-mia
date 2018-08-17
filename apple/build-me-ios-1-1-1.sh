#!/bin/bash -e
# @author AT

_configure() {
	# Configure
	if [ "x${DONT_CONFIGURE}" == "x" ]; then
		echo "Configuring ${PLATFORM}-${ARCH}..."
		(cd "${SRC_DIR}"; ./Configure ${COMPILER} "${CONFIGURE_OPTIONS}" --openssldir="${DST_DIR}" --prefix="${DST_DIR}" > "${LOG_FILE}" 2>&1)
	fi
}

_build() {
	# Build
	if [ "x${DONT_BUILD}" == "x" ]; then
		echo "Building ${PLATFORM}-${ARCH}..."
		(cd "${SRC_DIR}"; make >> "${LOG_FILE}" 2>&1)
	fi
}

build_ios() {
	for ARCH in $iOS_ARCHS; do
		PLATFORM="iPhoneOS"
		SRC_DIR="${FILES_DIR}/${PLATFORM}-${ARCH}"
		DST_DIR="${DIST_DIR}/${PLATFORM}-${ARCH}"
		LOG_FILE="${LOG_DIR}/${PLATFORM}${IOS_SDK}-${ARCH}.log"

    COMPILER="iphoneos-cross"
		CONFIGURE_OPTIONS="-arch ${ARCH}"

		# Select the compiler
		if [ "${ARCH}" == "i386" ]; then
			PLATFORM="iPhoneSimulator"
			COMPILER="iossimulator-xcrun"
			MIN_IOS="4.2"
		elif [ "${ARCH}" == "x86_64" ]; then
			PLATFORM="iPhoneSimulator"
			COMPILER="iossimulator-xcrun"
			MIN_IOS="7.0"
		elif [ "${ARCH}" == "arm64" ]; then
			MIN_IOS="7.0"
			COMPILER="ios64-xcrun"
    elif [ "${ARCH}" == "armv7" ]; then
      MIN_IOS="6.0"
			COMPILER="ios-xcrun"
    elif [ "${ARCH}" == "armv7s" ]; then
			COMPILER="ios-xcrun"
      MIN_IOS="6.0"
		else
			echo "ERROR: Unsupported architecture!"
		fi

    file_setup
		unarchive

		# Patch for armv7s
		if [ "${ARCH}" == "armv7s" ]; then
			sed -i'.bak' "s/armv7/armv7s/" "${SRC_DIR}/Configurations/15-ios.conf"
		fi
		
		_configure

		# Patch Makefile
    if [ "${ARCH}" == "x86_64" ]; then
			sed -i'.bak' "s/^CFLAG= -/CFLAG=  -miphoneos-version-min=$MIN_IOS -DOPENSSL_NO_ASM -/" "${SRC_DIR}/Makefile"
    else
			sed -i'.bak' "s/^CFLAG= -/CFLAG=  -miphoneos-version-min=$MIN_IOS -/" "${SRC_DIR}/Makefile"
    fi
    # Patch versions
    # some headers have moved starting 1.1
    sed -i'.bak' "s/^# define OPENSSL_VERSION_NUMBER.*$/# define OPENSSL_VERSION_NUMBER  $FAKE_NIBBLE/" "${SRC_DIR}/include/openssl/opensslv.h"
    sed -i'.bak' "s/^#  define OPENSSL_VERSION_TEXT.*$/#  define OPENSSL_VERSION_TEXT  \"$FAKE_TEXT\"/" "${SRC_DIR}/include/openssl/opensslv.h"

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
