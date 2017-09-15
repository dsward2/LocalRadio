#!/bin/sh

#  import_dylibs.sh
#  LocalRadio
#
#  Created by Douglas Ward on 5/14/17.
#  Copyright © 2017 ArkPhone LLC. All rights reserved.

# Modify MacPorts libraries for embed in application bundle

#https://github.com/auriamg/macdylibbundler
#dylibbundler -b -x ./LocalRadio.app/Contents/MacOS/LocalRadio -d ./MacPorts_Libraries/ -p @executable_path/../Frameworks/

#exit

EXECFILE=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}
#EXECFILE=/Users/dsward/Library/Developer/Xcode/DerivedData/LocalRadio-fypfuqvcbqkwibconllscqvxdnhj/Build/Products/Debug/LocalRadio.app/Contents/MacOS/LocalRadio

LIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}
#LIBPATH=/Users/dsward/Library/Developer/Xcode/DerivedData/LocalRadio-fypfuqvcbqkwibconllscqvxdnhj/Build/Products/Debug/LocalRadio.app/Contents/Frameworks

NEWLIBPATH="@executable_path/../Frameworks"

# Run dylibbundler against main app executable
echo dylibbundler -b -x "${EXECFILE}" -d "${LIBPATH}" -p "${NEWLIBPATH}"

dylibbundler -b -x "${EXECFILE}" -d "${LIBPATH}" -p "${NEWLIBPATH}"

exit

# list of dylibs in application bundle
TARGETS=(`ls "${LIBPATH}" | grep dylib`)
#TARGETS=libFLAC.8.dylib libcrypto.1.0.0.dylib libcurl.4.dylib libev.4.dylib libiconv.2.dylib libid3tag.0.3.0.dylib libmad.0.dylib libmagic.1.dylib libmp3lame.0.dylib libncurses.6.dylib libogg.0.dylib libopencore-amrnb.0.dylib libopencore-amrwb.0.dylib libopus.0.dylib libopusfile.0.dylib libpng16.16.dylib libreadline.7.0.dylib librtlsdr.0.5git.dylib libshout.3.dylib libsndfile.1.dylib libsox.3.dylib libspeex.1.dylib libssl.1.0.0.dylib libtag.1.17.0.dylib libtag_c.0.0.0.dylib libtheora.0.dylib libtwolame.0.dylib libusb-1.0.0.dylib libvorbis.0.dylib libvorbisenc.2.dylib libvorbisfile.3.dylib libwavpack.1.dylib libxml2.2.dylib libz.1.2.11.dylib

for TARGET in ${TARGETS[*]} ; do

	echo "1 " TARGET = ${TARGET}

	LIBFILE=${LIBPATH}/${TARGET}

	NEWTARGETID=${NEWLIBPATH}/${TARGET}
	
	echo "2 " LIBFILE = ${LIBFILE}
	echo "3 " NEWTARGETID = ${NEWTARGETID}

	# update the dependent library load paths in the library
    dyl_list=(`otool -L "${LIBFILE}" | grep local | awk '{print $1}'`)

	echo "4 " dyl_list = ${dyl_list}

    for dyl in ${dyl_list[*]}; do
    
        echo "5 " dyl = ${dyl}
    
        libname=$(basename ${dyl})
        libname=${libname%%.*}

        echo "6 " libname = ${libname}

        macos_libname=(`ls "/usr/lib/" | grep ${libname} | xargs basename`)

        echo "7 " macos_libname = ${macos_libname}

		if [ $macos_libname -gt "" ] ; then
			new_libname="@/usr/lib/${macos_libname}"
			bin=${LIBPATH}/${TARGET}
		
			quoted_dyl=$(printf %s "${dyl}" | sed "s/'/'\\\\''/g")
			quoted_new_libname=$(printf %s "${new_libname}" | sed "s/'/'\\\\''/g")
			quoted_filename=$(printf %s. "${bin}" | sed "s/'/'\\\\''/g")

			#code="install_name_tool -change '${quoted_dyl}' '${quoted_new_libname}' '${quoted_filename%.}'"

            code="dylibbundler -b -x ./LocalRadio.app/Contents/MacOS/LocalRadio -d ./MacPorts_Libraries/ -p @executable_path/../Frameworks/"

			echo "8 " code="$code"
			#eval "$code"

		else
			actual_libname=(`ls "/opt/local/lib/" | grep ${libname} | xargs basename`)
		
			new_libname="@executable_path/../Frameworks/${actual_libname}"
			bin=${LIBPATH}/${TARGET}
		
			quoted_dyl=$(printf %s "${dyl}" | sed "s/'/'\\\\''/g")
			quoted_new_libname=$(printf %s "${new_libname}" | sed "s/'/'\\\\''/g")
			quoted_filename=$(printf %s. "${bin}" | sed "s/'/'\\\\''/g")

			#code="install_name_tool -change '${quoted_dyl}' '${quoted_new_libname}' '${quoted_filename%.}'"

            code="dylibbundler -b -x ./LocalRadio.app/Contents/MacOS/LocalRadio -d ./MacPorts_Libraries/ -p @executable_path/../Frameworks/"

			echo "9 " code="$code"
			#eval "$code"
        
        fi
    done
done
