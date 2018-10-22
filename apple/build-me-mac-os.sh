#!/bin/bash -e
# @author AT

_configure_osx() {
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

_build_osx() {
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
		_configure_osx

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

		_build_osx
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
