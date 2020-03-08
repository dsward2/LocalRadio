#!/bin/sh

#  fix_sox.sh
#  LocalRadio
#
#  Created by Douglas Ward on 2/18/20.
#  Copyright © 2020 ArkPhone LLC. All rights reserved.

# This script is called from a build phase for LocalRadio.app

# Modify MacPorts tools and libraries for embed in application bundle

# install mackylibbundler from https://github.com/auriamg/macdylibbundler

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

# If the "Libraries_Modifed" directory exists in the built products directory,
# assume that this script is completed, libraries are copied, modified and ready to embed in app bundle.
if [ -d "${MODIFIEDLIBPATH}" ]; then
  exit 0
fi

cd ${BUILT_PRODUCTS_DIR}

if [ ! -d "${WORKLIBPATH}" ]; then
  mkdir ${WORKLIBPATH}
fi

if [ ! -d "${MODIFIEDLIBPATH}" ]; then
  mkdir ${MODIFIEDLIBPATH}
fi

SOXPATH=${BUILT_PRODUCTS_DIR}/sox
echo SOXPATH = ${SOXPATH}

echo cp ${SRCROOT}/sox/externals/sox/src/.libs/sox ${SOXPATH}
cp ${SRCROOT}/sox/externals/sox/src/.libs/sox ${SOXPATH}

echo cp ${SRCROOT}/sox/externals/sox/src/.libs/libsox.3.dylib ${BUILT_PRODUCTS_DIR}/Libraries_Modified/libsox.3.dylib
cp ${SRCROOT}/sox/externals/sox/src/.libs/libsox.3.dylib ${BUILT_PRODUCTS_DIR}/Libraries_Modified/libsox.3.dylib

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

#echo install_name_tool -change /opt/local/lib/libvorbisenc.2.dylib @executable_path/../Frameworks/libvorbisenc.2.dylib ${SOXPATH}
#install_name_tool -change /opt/local/lib/libvorbisenc.2.dylib @executable_path/../Frameworks/libvorbisenc.2.dylib ${SOXPATH}

#echo install_name_tool -change /opt/local/lib/libvorbisfile.3.dylib @executable_path/../Frameworks/libvorbisfile.3.dylib ${SOXPATH}
#install_name_tool -change /opt/local/lib/libvorbisfile.3.dylib @executable_path/../Frameworks/libvorbisfile.3.dylib ${SOXPATH}

#echo install_name_tool -change /opt/local/lib/libvorbis.0.dylib @executable_path/../Frameworks/libvorbis.0.dylib ${SOXPATH}
#install_name_tool -change /opt/local/lib/libvorbis.0.dylib @executable_path/../Frameworks/libvorbis.0.dylib ${SOXPATH}

#echo install_name_tool -change /opt/local/lib/libogg.0.dylib @executable_path/../Frameworks/libogg.0.dylib ${SOXPATH}
#install_name_tool -change /opt/local/lib/libogg.0.dylib @executable_path/../Frameworks/libogg.0.dylib ${SOXPATH}


#####################################################################

echo Copy libraries to Libraries_Modified folder

# Now fix the libraries copied from MacPorts to load other interdependent libraries from the app bundle instead

cd ${BUILT_PRODUCTS_DIR}

# Run dylibbundler against main app executable

echo /opt/local/bin/dylibbundler -b -x "${EXECFILE}" -d "${MODIFIEDLIBPATH}" -p "${NEWLOADERPATH}"

# list of dylibs in application bundle
#TARGETS=(`ls "${BUNDLELIBPATH}" | grep dylib`)

# TARGETS should list the same files in Project Navigator in the Libraries_Modified folder, except for libsox

TARGETS="libfftw3f.3.dylib libFLAC.8.dylib libliquid.dylib libltdl.7.dylib libogg.0.dylib librtlsdr.0.6git.dylib libsndfile.1.dylib libusb-1.0.0.dylib libvorbis.0.dylib libvorbisenc.2.dylib libvorbisfile.3.dylib"

for TARGET in ${TARGETS[*]} ; do

    echo "1 " TARGET = ${TARGET}

    MACPORTSLIBFILE=/opt/local/lib/${TARGET}
    echo "2 " MACPORTSLIBFILE = ${MACPORTSLIBFILE}

    #LIBFILE=${BUNDLELIBPATH}/${TARGET}
    TARGETPATH=${BUILT_PRODUCTS_DIR}/${TARGET}
    echo "3 " TARGETPATH = ${TARGETPATH}

    #NEWTARGETID=${NEWLOADERPATH}/${TARGET}
    #echo "4 " NEWTARGETID = ${NEWTARGETID}

    if [ ! -d "${MODIFIEDLIBPATH}/${TARGET}" ]; then

        # update the dependent library load paths in the library
        dyl_list=(`otool -L "${MACPORTSLIBFILE}" | grep local | awk '{print $1}'`)

        echo "5 " dyl_list = ${dyl_list}

        for dyl in ${dyl_list[*]}; do

            echo "6 " dyl = ${dyl}

            libname=$(basename ${dyl})
            libname=${libname%%.*}

            echo "7 " libname = ${libname}

            macos_libname=(`ls "/usr/lib/" | grep ${libname} | xargs basename`)

            echo "8 " macos_libname = ${macos_libname}

            #if [ $macos_libname -gt "" ] ; then
            if [ ! -z $macos_libname ] ; then
                new_libname="@/usr/lib/${macos_libname}"
                bin=${BUNDLELIBPATH}/${TARGET}

                quoted_dyl=$(printf %s "${dyl}" | sed "s/'/'\\\\''/g")
                quoted_new_libname=$(printf %s "${new_libname}" | sed "s/'/'\\\\''/g")
                quoted_filename=$(printf %s. "${bin}" | sed "s/'/'\\\\''/g")

                #code="install_name_tool -change '${quoted_dyl}' '${quoted_new_libname}' '${quoted_filename%.}'"

                code="/opt/local/bin/dylibbundler -b -x ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/LocalRadio -d ./LocalRadio.app/Contents/Frameworks -p ${NEWLOADERPATH}"

                echo "9 " code="$code"
                #eval "$code"

            else
                actual_libname=(`ls "/opt/local/lib/" | grep ${libname} | xargs basename`)

                new_libname="@executable_path/../Frameworks/${actual_libname}"
                bin=${BUNDLELIBPATH}/${TARGET}

                quoted_dyl=$(printf %s "${dyl}" | sed "s/'/'\\\\''/g")
                quoted_new_libname=$(printf %s "${new_libname}" | sed "s/'/'\\\\''/g")
                quoted_filename=$(printf %s. "${bin}" | sed "s/'/'\\\\''/g")

                #code="install_name_tool -change '${quoted_dyl}' '${quoted_new_libname}' '${quoted_filename%.}'"

                echo cp ${MACPORTSLIBFILE} ${WORKLIBPATH}
                cp ${MACPORTSLIBFILE} ${WORKLIBPATH}

                WORKLIBFILE=${BUILT_PRODUCTS_DIR}/Libraries_Copy/

                code="/opt/local/bin/dylibbundler -b -of -x ${WORKLIBPATH}/${TARGET} -d ${MODIFIEDLIBPATH} -p ${NEWLOADERPATH}"

                 echo "10 " code="$code"
                 eval "$code"
            fi
        done
    else
        echo "11 " ${MODIFIEDLIBPATH}/${TARGET} exists
    fi
done

#####################################################################

# rename librtlsdr.0.6git.dylib to librtlsdr.0.dylib

echo mv ${MODIFIEDLIBPATH}/librtlsdr.0.6git.dylib ${MODIFIEDLIBPATH}/librtlsdr.0.dylib
mv ${MODIFIEDLIBPATH}/librtlsdr.0.6git.dylib ${MODIFIEDLIBPATH}/librtlsdr.0.dylib

echo install_name_tool -id @executable_path/../Frameworks/librtlsdr.0.dylib ${MODIFIEDLIBPATH}/librtlsdr.0.dylib
install_name_tool -id @executable_path/../Frameworks/librtlsdr.0.dylib ${MODIFIEDLIBPATH}/librtlsdr.0.dylib

