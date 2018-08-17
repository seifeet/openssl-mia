#!/bin/bash -e
# @author AT

# Unarchive and copy OpenSSL files
unarchive() {
  echo "Unarchive sources for ${PLATFORM}-${ARCH}..."
  (cd "${BUILD_DIR}"; tar -C ${FILES_DIR} -zxf "${OPENSSL_PATH}"; cp -a "${FILES_DIR}/${OPENSSL_NAME}/" "${SRC_DIR}";)
}

#   linux-x86_64
#   darwin-x86_64
compute_host_tag() {
  HOST_OS=`uname -s`
  HOST_ARCH=x86_64
  case "$HOST_OS" in
      Darwin)
          HOST_OS=darwin
          ;;
      Linux)
          # note that building  32-bit binaries on x86_64 is handled later
          HOST_OS=linux
          ;;
  esac
  export HOST_TAG=${HOST_OS}-${HOST_ARCH}
}

# Create all the needed folders
# and download OpenSSL source
file_setup() {
  # Remove folders if needed
  if [ -d "${SRC_DIR}" ]; then
    echo "Remove folder ${SRC_DIR}..."
    rm -rf ${SRC_DIR};
  fi

  if [ -d "${DIST_DIR}" ]; then
    echo "Remove folder ${DIST_DIR}..."
    rm -rf ${DIST_DIR};
  fi

  # Create folders if needed
  if [ ! -d "${SRC_DIR}" ]; then
    echo "Create folder ${SRC_DIR}..."
    mkdir -p ${SRC_DIR};
  fi

  if [ ! -d "${DIST_DIR}" ]; then
    echo "Create folder ${DIST_DIR}..."
    mkdir -p ${DIST_DIR};
  fi

  if [ ! -d "${LOG_DIR}" ]; then
    echo "Create folder ${LOG_DIR}..."
    mkdir -p ${LOG_DIR};
  fi

  # Retrieve OpenSSL tarbal if needed
  if [ ! -e "${OPENSSL_PATH}" ]; then
    curl "$OPENSSL_URL" -o "${OPENSSL_PATH}"
  fi
}

# Compare two strings in dot separated version format
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if [[ "${ver1[i]}" > "${ver2[i]}" ]]
        then
            return 1
        fi
        if [[ "${ver1[i]}" < "${ver2[i]}" ]]
        then
            return 2
        fi
    done
    return 0
}
