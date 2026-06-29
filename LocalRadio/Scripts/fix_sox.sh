#!/bin/sh

#  fix_sox.sh
#  LocalRadio
#
#  Created by Douglas Ward on 2/18/20.
#  Copyright © 2020 ArkPhone LLC. All rights reserved.

# This script is called from a build phase for LocalRadio.app.
# Run Xcode's 'Clean Build Folder' if this list is changed.

# Modify MacPorts tools and libraries for embed in application bundle

# install macdylibbundler from https://github.com/auriamg/macdylibbundler

echo BUILT_PRODUCTS_DIR = ${BUILT_PRODUCTS_DIR}

EXECFILE=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}
echo EXECFILE = ${EXECFILE}

#BUNDLELIBPATH=/Users/dsward/Library/Developer/Xcode/DerivedData/LocalRadio-fypfuqvcbqkwibconllscqvxdnhj/Build/Products/Debug/LocalRadio.app/Contents/Frameworks
BUNDLELIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}
echo BUNDLELIBPATH = ${BUNDLELIBPATH}

WORKLIBPATH=${BUILT_PRODUCTS_DIR}/Libraries_Copy
echo WORKLIBPATH = ${WORKLIBPATH}

MODIFIEDLIBPATH=${BUILT_PRODUCTS_DIR}/Libraries_Modified
echo MODIFIEDLIBPATH = ${MODIFIEDLIBPATH}

NEWLOADERPATH="@executable_path/../Frameworks"

# Always regenerate Libraries_Modified so changes to the library list or to the
# source dylibs are picked up on every build. Remove any previous copy first.

cd ${BUILT_PRODUCTS_DIR}

rm -rf "${WORKLIBPATH}" "${MODIFIEDLIBPATH}"
mkdir "${WORKLIBPATH}"
mkdir "${MODIFIEDLIBPATH}"

SOXPATH="${BUILT_PRODUCTS_DIR}/sox"
echo SOXPATH = "${SOXPATH}"

echo cp "${SRCROOT}/sox/externals/sox/src/.libs/sox" "${SOXPATH}"
cp "${SRCROOT}/sox/externals/sox/src/.libs/sox" "${SOXPATH}"

echo cp "${SRCROOT}/sox/externals/sox/src/.libs/libsox.3.dylib" "${BUILT_PRODUCTS_DIR}/Libraries_Modified/libsox.3.dylib"
cp "${SRCROOT}/sox/externals/sox/src/.libs/libsox.3.dylib" "${BUILT_PRODUCTS_DIR}/Libraries_Modified/libsox.3.dylib"

echo install_name_tool -id @executable_path/../Frameworks/libsox.3.dylib ${BUILT_PRODUCTS_DIR}/Libraries_Modified/libsox.3.dylib
install_name_tool -id @executable_path/../Frameworks/libsox.3.dylib ${BUILT_PRODUCTS_DIR}/Libraries_Modified/libsox.3.dylib

#####################################################################

# fix sox library loading paths

echo "fix sox library loading paths"

echo install_name_tool -change /usr/local/opt/libtool/lib/libltdl.7.dylib @executable_path/../Frameworks/libltdl.7.dylib ${SOXPATH}

install_name_tool -change /usr/local/opt/libtool/lib/libltdl.7.dylib @executable_path/../Frameworks/libltdl.7.dylib ${SOXPATH}

echo install_name_tool -change /usr/local/opt/libtool/lib/libltdl.7.dylib @executable_path/../Frameworks/libltdl.7.dylib ${BUILT_PRODUCTS_DIR}/Libraries_Modified/libsox.3.dylib

install_name_tool -change /usr/local/opt/libtool/lib/libltdl.7.dylib @executable_path/../Frameworks/libltdl.7.dylib ${BUILT_PRODUCTS_DIR}/Libraries_Modified/libsox.3.dylib

echo install_name_tool -change /usr/local/lib/libsox.3.dylib @executable_path/../Frameworks/libsox.3.dylib ${SOXPATH}
install_name_tool -change /usr/local/lib/libsox.3.dylib @executable_path/../Frameworks/libsox.3.dylib ${SOXPATH}

#####################################################################

echo "Copy libraries to Libraries_Modified folder"

# Now fix the libraries copied from MacPorts to load other interdependent libraries from the app bundle instead

cd ${BUILT_PRODUCTS_DIR}

# Run dylibbundler against main app executable

echo /opt/local/bin/dylibbundler -b -x "${EXECFILE}" -d "${MODIFIEDLIBPATH}" -p "${NEWLOADERPATH}"

# list of dylibs in application bundle
#TARGETS=(`ls "${BUNDLELIBPATH}" | grep dylib`)

# TARGETS should list the same files in Project Navigator in the Libraries_Modified folder, except for libsox

TARGETS="libao.4.dylib libfec.dylib libfftw3f.3.dylib libFLAC.14.dylib libliquid.dylib libltdl.7.dylib libogg.0.dylib librtlsdr.0.dylib libsndfile.1.dylib libusb-1.0.0.dylib libvorbis.0.dylib libvorbisenc.2.dylib libvorbisfile.3.dylib"

# Pass 1: Copy each MacPorts library into Libraries_Modified and set its own
# install id to a bundle-relative path. (dylibbundler only copies a library's
# dependencies, not the -x library itself, so we must place each target here.)

for TARGET in ${TARGETS} ; do

    echo "TARGET = ${TARGET}"

    MACPORTSLIBFILE=/opt/local/lib/${TARGET}

    if [ ! -f "${MACPORTSLIBFILE}" ]; then
        echo "WARNING: ${MACPORTSLIBFILE} not found in MacPorts - skipping"
        continue
    fi

    cp "${MACPORTSLIBFILE}" "${MODIFIEDLIBPATH}/${TARGET}"
    chmod u+w "${MODIFIEDLIBPATH}/${TARGET}"

    install_name_tool -id @executable_path/../Frameworks/${TARGET} "${MODIFIEDLIBPATH}/${TARGET}"
done

# Pass 2: Run dylibbundler against every library now in Libraries_Modified so
# their interdependent load paths are rewritten to the app bundle's Frameworks
# folder, pulling in any additional dependencies (e.g. opus, mpg123, mp3lame).

for LIB in "${MODIFIEDLIBPATH}"/*.dylib ; do
    echo "dylibbundler: ${LIB}"
    /opt/local/bin/dylibbundler -b -of -x "${LIB}" -d "${MODIFIEDLIBPATH}" -p "${NEWLOADERPATH}"
done

#####################################################################

# Embed the complete set of bundled libraries into the app's Frameworks folder.
#
# dylibbundler has already gathered the full transitive dependency closure into
# Libraries_Modified (with every load path rewritten to @executable_path/../Frameworks).
# Copying ALL of them here - rather than relying on a hand-maintained list in the
# "Copy Libraries" build phase - means new transitive dependencies (e.g. when a
# MacPorts library starts pulling in opus / mpg123 / mp3lame) are embedded
# automatically and never go missing at runtime.

echo "Embedding libraries into ${BUNDLELIBPATH}"
mkdir -p "${BUNDLELIBPATH}"
cp -f "${MODIFIEDLIBPATH}"/*.dylib "${BUNDLELIBPATH}/"

# Code-sign each embedded library with the build's signing identity (falling back
# to ad-hoc) so the app's outer signature validates and the libraries load.
SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${CODE_SIGN_IDENTITY:--}}"
echo "Code-signing embedded libraries with identity: ${SIGN_IDENTITY}"
for dylib in "${BUNDLELIBPATH}"/*.dylib ; do
    codesign --force --timestamp=none --sign "${SIGN_IDENTITY}" "${dylib}"
done

echo "Current contents of Libraries_Copied folder: ${WORKLIBPATH}"
ls -l ${WORKLIBPATH}
echo "Current contents of Libraries_Modified folder: ${MODIFIEDLIBPATH}"
ls -l ${MODIFIEDLIBPATH}



echo "End fix_sox.sh"

exit; # test June 28, 2026

#####################################################################

# MacPorts now ships librtlsdr.0.dylib directly (symlink to librtlsdr.2.0.1.dylib),
# so no rename is needed; just reassert the bundle-relative install id.

echo "Run install_name_tool for librtlsdr.0.dylib"

echo install_name_tool -id @executable_path/../Frameworks/librtlsdr.0.dylib "${MODIFIEDLIBPATH}/librtlsdr.0.dylib"
install_name_tool -id @executable_path/../Frameworks/librtlsdr.0.dylib "${MODIFIEDLIBPATH}/librtlsdr.0.dylib"

