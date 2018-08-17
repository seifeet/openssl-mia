#!/bin/bash -e
# @author AT

# needed because of the change in sysroot location in r14
# for android ndk r13
# export ="${NDK_DIR}/platforms/android-${OPENSSL_TARGET_API}/arch-${TOOLCHAIN_ARCH}/usr/include"
export SYSROOT_INC="${NDK_DIR}/sysroot/usr/include"

NDK_MAKE_TOOLCHAIN="${NDK_DIR}/build/tools/make-standalone-toolchain.sh"

_env_check() {
  if [ ! -d "${NDK_DIR}" ]; then
    echo "Please update NDK_DIR. NDK not found: ${NDK_DIR}..."
    exit 1
  fi

  if [ ! -f "${NDK_MAKE_TOOLCHAIN}" ]; then
    echo "Please update NDK_MAKE_TOOLCHAIN. NDK toolchain not found: ${NDK_MAKE_TOOLCHAIN}..."
    exit 1
  fi
}

_var_setup() {
  if [ "${TARGET_ABI}" == "armeabi-v7a" ]
  then
    TOOLCHAIN_ARCH=arm
    export TOOLCHAIN_PATH="${SRC_DIR}/android-toolchain-${TOOLCHAIN_ARCH}/bin"
    export TOOLCHAIN_PREFIX=${TOOLCHAIN_ARCH}-linux-androideabi
    export TOOLCHAIN=${TOOLCHAIN_ARCH}-linux-androideabi-${OPENSSL_GCC_VERSION}
    export NDK_TOOLCHAIN_BASENAME=${TOOLCHAIN_PATH}/${TOOLCHAIN_PREFIX}
    export ARCH_FLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16"
    export ARCH_LINK="-march=armv7-a -Wl,--fix-cortex-a8"
    export CONFIGURE_ARCH="android"
  elif [ "${TARGET_ABI}" == "arm64-v8a" ]
  then
    TOOLCHAIN_ARCH=arm64
    export TOOLCHAIN_PATH="${SRC_DIR}/android-toolchain-${TOOLCHAIN_ARCH}/bin"
    export TOOLCHAIN_PREFIX=aarch64-linux-android
    export TOOLCHAIN="aarch64-linux-android-${OPENSSL_GCC_VERSION}"
    export NDK_TOOLCHAIN_BASENAME=${TOOLCHAIN_PATH}/${TOOLCHAIN_PREFIX}
    export ARCH_FLAGS=""
    export ARCH_LINK=""
    if [[ ${OPENSSL_VERSION_NUM} < 1.1 ]]; then
      export CONFIGURE_ARCH="android"
    else
      export CONFIGURE_ARCH="android64-aarch64"
    fi
elif [ "${TARGET_ABI}" == "armeabi" ]
  then
    TOOLCHAIN_ARCH=arm
    export TOOLCHAIN_PATH="${SRC_DIR}/android-toolchain-${TOOLCHAIN_ARCH}/bin"
    export TOOLCHAIN_PREFIX=${TOOLCHAIN_ARCH}-linux-androideabi
    export TOOLCHAIN=${TOOLCHAIN_ARCH}-linux-androideabi-${OPENSSL_GCC_VERSION}
    export NDK_TOOLCHAIN_BASENAME=${TOOLCHAIN_PATH}/${TOOLCHAIN_PREFIX}
    export ARCH_FLAGS="-mthumb"
    export ARCH_LINK=""
    export CONFIGURE_ARCH="android"
  elif [ "${TARGET_ABI}" == "x86" ]
  then
    TOOLCHAIN_ARCH=x86
    export TOOLCHAIN_PATH="${SRC_DIR}/android-toolchain-${TOOLCHAIN_ARCH}/bin"
    export TOOLCHAIN_PREFIX=i686-linux-android
    export TOOLCHAIN=${TOOLCHAIN_ARCH}-${OPENSSL_GCC_VERSION}
    export NDK_TOOLCHAIN_BASENAME=${TOOLCHAIN_PATH}/${TOOLCHAIN_PREFIX}
    export ARCH_FLAGS="-march=i686 -msse3 -mstackrealign -mfpmath=sse"
    export ARCH_LINK=""
    export CONFIGURE_ARCH="android-x86"
  elif [ "${TARGET_ABI}" == "x86_64" ]
  then
    TOOLCHAIN_ARCH=x86_64
    export TOOLCHAIN_PATH="${SRC_DIR}/android-toolchain-${TOOLCHAIN_ARCH}/bin"
    export TOOLCHAIN_PREFIX=${TOOLCHAIN_ARCH}-linux-android
    export TOOLCHAIN="${TOOLCHAIN_ARCH}-${OPENSSL_GCC_VERSION}"
    export NDK_TOOLCHAIN_BASENAME=${TOOLCHAIN_PATH}/${TOOLCHAIN_PREFIX}
    export ARCH_FLAGS=""
    export ARCH_LINK=""
    export CONFIGURE_ARCH="linux-${TOOLCHAIN_ARCH}"
  else
    echo "Unsupported target ABI: ${TARGET_ABI}"
    exit 1
  fi
}


function build_library {
  _env_check
  file_setup
  _var_setup

  unarchive

  export CC=${NDK_TOOLCHAIN_BASENAME}-gcc
  export CXX=${NDK_TOOLCHAIN_BASENAME}-g++
  export LINK=${CXX}
  export LD=${NDK_TOOLCHAIN_BASENAME}-ld
  export AR=${NDK_TOOLCHAIN_BASENAME}-ar
  export RANLIB=${NDK_TOOLCHAIN_BASENAME}-ranlib
  export STRIP=${NDK_TOOLCHAIN_BASENAME}-strip
  export CROSS_SYSROOT="${NDK_DIR}/platforms/android-${OPENSSL_TARGET_API}/arch-${TOOLCHAIN_ARCH}"
  export CPPFLAGS=" ${ARCH_FLAGS} -fpic -ffunction-sections -funwind-tables -fstack-protector -fno-strict-aliasing -finline-limit=64 "
  export CXXFLAGS=" ${ARCH_FLAGS} -fpic -ffunction-sections -funwind-tables -fstack-protector -fno-strict-aliasing -finline-limit=64 -frtti -fexceptions "
  export CFLAGS=" ${ARCH_FLAGS} -fpic -ffunction-sections -funwind-tables -fstack-protector -fno-strict-aliasing -finline-limit=64 "
  export LDFLAGS=" ${ARCH_LINK} "

  # cope the toolchain locally
  ${NDK_MAKE_TOOLCHAIN} --platform=android-${OPENSSL_TARGET_API} \
                        --toolchain=${TOOLCHAIN} \
                        --install-dir="${SRC_DIR}/android-toolchain-${TOOLCHAIN_ARCH}"

  # some options were deprecated starting 1.1
  # no-ssl2
  if [[ ${OPENSSL_VERSION_NUM} < 1.1 ]]; then
    CONFIGURE_OPTIONS="shared no-threads no-asm no-zlib no-ssl2 no-ssl3 no-comp no-hw no-engine"
  else
    CONFIGURE_OPTIONS="shared no-threads no-asm no-zlib no-ssl3 no-comp no-hw no-engine"
  fi
  CONFIGURE_OPTIONS="${CONFIGURE_ARCH} ${CONFIGURE_OPTIONS}"

  cd ${SRC_DIR}
  ./Configure ${CONFIGURE_OPTIONS} \
       --openssldir="${DIST_DIR}" --prefix="${DIST_DIR}" \
       -I${SYSROOT_INC} -I${SYSROOT_INC}/${TOOLCHAIN_PREFIX} \
       > "${LOG_FILE}" 2>&1
  export PATH=$TOOLCHAIN_PATH:$PATH
  make depend >> "${LOG_FILE}" 2>&1
  make >> "${LOG_FILE}" 2>&1
  make install >> "${LOG_FILE}" 2>&1
  echo "Build completed! Check output libraries in ${DIST_DIR}"
}
