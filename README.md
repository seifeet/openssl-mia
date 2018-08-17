# openssl-mia
OpenSSL for Mac, iOS and Android is based on https://github.com/taskworld/openssl-mobile

### Instructions

#### Android:
1. Download and unarchive Android NDK from https://developer.android.com/ndk/downloads/

2. Update NDK_DIR variable in android/build-me.sh to point the correct NDK location
   If needed, adjust the following variables.
   OPENSSL_TARGET_API
   OPENSSL_GCC_VERSION
   OPENSSL_VERSION

3. From the root folder of openssl-mia run
   $ ./android/build-me.sh all
   or any of the following:
   $ ./android/build-me.sh armeabi
   $ ./android/build-me.sh armeabi-v7a
   $ ./android/build-me.sh x86
   $ ./android/build-me.sh x86_64
   $ ./android/build-me.sh arm64-v8a

4. The compiled library will be located in ./build/dist/android/$OPENSSL_NAME/${TARGET_ABI}

#### Mac, iOS

1. Make sure XCode is installed and adjust the following variables in apple/build-me.sh.
   OSX_SDK
   MIN_OSX
   IOS_SDK
   OPENSSL_VERSION

3. From the root folder of openssl-mia run
   $ ./apple/build-me.sh

3. The compiled library will be located in ./build/dist/apple/$OPENSSL_NAME/${TARGET_PLATFORM}

#### Tested OpenSSL versions
1. 1.0.2e
2. 1.0.2o
3. 1.1.0h
4. 1.1.0i
5. 1.1.1-pre8

#### Tested Android NDK versions
1. android-ndk-r17b
2. android-ndk-r16b
3. android-ndk-r15c
4. android-ndk-r14b
5. android-ndk-r13b

#### Caveats
1. Starting 1.1.1 OpenSSL introduced Android specific architecture configurations
2. For iOS, both armv7 & armv7s can be neglected at this point (less than 0.1% of devices have iOS < 7)
