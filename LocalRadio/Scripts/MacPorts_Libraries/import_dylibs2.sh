#!/bin/sh

#  import_dylibs.sh
#  LocalRadio
#
#  Created by Douglas Ward on 5/14/17.
#  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.

# Modify MacPorts libraries for embed in application bundle

#https://github.com/auriamg/macdylibbundler
#dylibbundler -b -x ./LocalRadio.app/Contents/MacOS/LocalRadio -d ./MacPorts_Libraries/ -p @executable_path/../Frameworks/

echo BUILT_PRODUCTS_DIR = ${BUILT_PRODUCTS_DIR}

#EXECFILE=/Users/dsward/Library/Developer/Xcode/DerivedData/LocalRadio-fypfuqvcbqkwibconllscqvxdnhj/Build/Products/Debug/LocalRadio.app/Contents/MacOS/LocalRadio
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

#####################################################################

SOXPATH=${SRCROOT}/LocalRadio/MacPorts_Tools/sox

echo SOXPATH = ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libsox.3.dylib @executable_path/../Frameworks/libsox.3.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libsox.3.dylib @executable_path/../Frameworks/libsox.3.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libpng16.16.dylib @executable_path/../Frameworks/libpng16.16.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libpng16.16.dylib @executable_path/../Frameworks/libpng16.16.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libmagic.1.dylib @executable_path/../Frameworks/libmagic.1.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libmagic.1.dylib @executable_path/../Frameworks/libmagic.1.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libFLAC.8.dylib @executable_path/../Frameworks/libFLAC.8.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libFLAC.8.dylib @executable_path/../Frameworks/libFLAC.8.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libmad.0.dylib @executable_path/../Frameworks/libmad.0.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libmad.0.dylib @executable_path/../Frameworks/libmad.0.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libid3tag.0.dylib @executable_path/../Frameworks/libid3tag.0.3.0.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libid3tag.0.dylib @executable_path/../Frameworks/libid3tag.0.3.0.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libz.1.dylib @executable_path/../Frameworks/libz.1.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libz.1.dylib @executable_path/../Frameworks/libz.1.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libmp3lame.0.dylib @executable_path/../Frameworks/libmp3lame.0.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libmp3lame.0.dylib @executable_path/../Frameworks/libmp3lame.0.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libtwolame.0.dylib @executable_path/../Frameworks/libtwolame.0.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libtwolame.0.dylib @executable_path/../Frameworks/libtwolame.0.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libopusfile.0.dylib @executable_path/../Frameworks/libopusfile.0.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libopusfile.0.dylib @executable_path/../Frameworks/libopusfile.0.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libvorbisenc.2.dylib @executable_path/../Frameworks/libvorbisenc.2.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libvorbisenc.2.dylib @executable_path/../Frameworks/libvorbisenc.2.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libvorbisfile.3.dylib @executable_path/../Frameworks/libvorbisfile.3.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libvorbisfile.3.dylib @executable_path/../Frameworks/libvorbisfile.3.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libvorbis.0.dylib @executable_path/../Frameworks/libvorbis.0.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libvorbis.0.dylib @executable_path/../Frameworks/libvorbis.0.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libogg.0.dylib @executable_path/../Frameworks/libogg.0.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libogg.0.dylib @executable_path/../Frameworks/libogg.0.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libwavpack.1.dylib @executable_path/../Frameworks/libwavpack.1.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libwavpack.1.dylib @executable_path/../Frameworks/libwavpack.1.dylib ${SOXPATH}

echo install_name_tool -change /opt/local/lib/libsndfile.1.dylib @executable_path/../Frameworks/libsndfile.1.dylib ${SOXPATH}
install_name_tool -change /opt/local/lib/libsndfile.1.dylib @executable_path/../Frameworks/libsndfile.1.dylib ${SOXPATH}

#####################################################################

cd ${BUILT_PRODUCTS_DIR}

if [ ! -d "${WORKLIBPATH}" ]; then
  mkdir ${WORKLIBPATH}
fi

if [ ! -d "${MODIFIEDLIBPATH}" ]; then
  mkdir ${MODIFIEDLIBPATH}
fi

# Run dylibbundler against main app executable
#echo dylibbundler -b -x "${EXECFILE}" -d "${LIBPATH}" -p "${NEWLOADERPATH}"
echo /opt/local/bin/dylibbundler -b -x "${EXECFILE}" -d "${MODIFIEDLIBPATH}" -p "${NEWLOADERPATH}"
#/opt/local/bin/dylibbundler -b -x "${EXECFILE}" -d "${MODIFIEDLIBPATH}" -p "${NEWLOADERPATH}"



# list of dylibs in application bundle
#TARGETS=(`ls "${BUNDLELIBPATH}" | grep dylib`)

#TARGETS="libao.4.dylib libev.4.dylib libfftw3f.3.dylib libFLAC.8.dylib libiconv.2.dylib libid3tag.0.3.0.dylib libliquid.dylib liblzma.5.dylib libmad.0.dylib libmagic.1.dylib libmp3lame.0.dylib libncurses.6.dylib libogg.0.dylib libopencore-amrnb.0.dylib libopencore-amrwb.0.dylib libopus.0.dylib libopusfile.0.dylib libpng16.16.dylib libreadline.7.0.dylib libshout.3.dylib libsndfile.1.dylib libsox.3.dylib libspeex.1.dylib libsqlite3.0.dylib libtag_c.0.0.0.dylib libtag.1.17.0.dylib libtheora.0.dylib libtwolame.0.dylib libusb-1.0.0.dylib libvorbis.0.dylib libvorbisenc.2.dylib libvorbisfile.3.dylib libwavpack.1.dylib"


TARGETS="libao.4.dylib libev.4.dylib libfftw3f.3.dylib libFLAC.8.dylib libid3tag.0.3.0.dylib libliquid.dylib libmad.0.dylib libmagic.1.dylib libmp3lame.0.dylib libogg.0.dylib libopus.0.dylib libopusfile.0.dylib libpng16.16.dylib libsndfile.1.dylib libsox.3.dylib libspeex.1.dylib libtheora.0.dylib libtwolame.0.dylib libusb-1.0.0.dylib libvorbis.0.dylib libvorbisenc.2.dylib libvorbisfile.3.dylib libwavpack.1.dylib"


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



