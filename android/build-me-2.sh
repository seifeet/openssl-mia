#!/bin/bash -e
# @author AT

_env_check() {
  if [ ! -d "${NDK_DIR}" ]; then
    echo "Please update NDK_DIR. NDK not found: ${NDK_DIR}..."
    exit 1
  fi
}

_var_setup() {
  if [ "${TARGET_ABI}" == "armeabi-v7a" ]
  then
    export TOOLCHAIN_ARCH="arm-linux-androideabi-${OPENSSL_GCC_VERSION}"
    export ARCH_FLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16"
    export ARCH_LINK="-march=armv7-a -Wl,--fix-cortex-a8"
    export CONFIGURE_ARCH="android-arm"
  elif [ "${TARGET_ABI}" == "arm64-v8a" ]
  then
    export TOOLCHAIN_ARCH="aarch64-linux-android-${OPENSSL_GCC_VERSION}"
    export ARCH_FLAGS=""
    export ARCH_LINK=""
    export CONFIGURE_ARCH="android-arm64"
elif [ "${TARGET_ABI}" == "armeabi" ]
  then
    export TOOLCHAIN_ARCH="arm-linux-androideabi-${OPENSSL_GCC_VERSION}"
    export ARCH_FLAGS="-mthumb"
    export ARCH_LINK=""
    export CONFIGURE_ARCH="android-arm"
  elif [ "${TARGET_ABI}" == "x86" ]
  then
    export TOOLCHAIN_ARCH="x86-${OPENSSL_GCC_VERSION}"
    export ARCH_FLAGS="-march=i686 -msse3 -mstackrealign -mfpmath=sse"
    export ARCH_LINK=""
    export CONFIGURE_ARCH="android-x86"
  elif [ "${TARGET_ABI}" == "x86_64" ]
  then
    export TOOLCHAIN_ARCH="x86_64-${OPENSSL_GCC_VERSION}"
    export ARCH_FLAGS=""
    export ARCH_LINK=""
    export CONFIGURE_ARCH="android-x86_64"
  else
    echo "Unsupported target ABI: ${TARGET_ABI}"
    exit 1
  fi
}

function build_library {
  _env_check
  file_setup
  _var_setup

  compute_host_tag
  unarchive

  export ANDROID_NDK="${NDK_DIR}"

  export CC=gcc
  export CXX=g++
  export LINK=${CXX}
  export LD=ld
  export AR=ar
  export RANLIB=ranlib
  export STRIP=strip
  export CPPFLAGS=" ${ARCH_FLAGS} -fpic -ffunction-sections -funwind-tables -fstack-protector -fno-strict-aliasing -finline-limit=64 "
  export CXXFLAGS=" ${ARCH_FLAGS} -fpic -ffunction-sections -funwind-tables -fstack-protector -fno-strict-aliasing -finline-limit=64 -frtti -fexceptions "
  export CFLAGS=" ${ARCH_FLAGS} -fpic -ffunction-sections -funwind-tables -fstack-protector -fno-strict-aliasing -finline-limit=64 "
  export LDFLAGS=" ${ARCH_LINK} "
  export PATH="$ANDROID_NDK/toolchains/${TOOLCHAIN_ARCH}/prebuilt/${HOST_TAG}/bin:$PATH"

  CONFIGURE_OPTIONS="shared no-threads no-asm no-zlib no-ssl3 no-comp no-hw no-engine"
  CONFIGURE_OPTIONS="${CONFIGURE_ARCH} ${CONFIGURE_OPTIONS}"

  cd ${SRC_DIR}
  echo $PATH
  ./Configure ${CONFIGURE_OPTIONS} \
       --openssldir="${DIST_DIR}" --prefix="${DIST_DIR}" \
       -D__ANDROID_API__=${OPENSSL_TARGET_API} \
       > "${LOG_FILE}" 2>&1

  make depend >> "${LOG_FILE}" 2>&1
  make >> "${LOG_FILE}" 2>&1
  make install >> "${LOG_FILE}" 2>&1
  echo "Build completed! Check output libraries in ${DIST_DIR}"
}
