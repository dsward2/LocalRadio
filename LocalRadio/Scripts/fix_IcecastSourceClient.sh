#!/bin/sh

#  fix_IcecastSourceClient.sh
#  LocalRadio
#
#  Created by Douglas Ward on 7/28/18.
#  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.

#  Fix libshout to load properly for IcecastSourceClient
#  Fix libvorbis, libssl, libcrypto, libtheora, libogg to load properly for libshout

EXECFILE=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}

EXECFOLDER=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}

LIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}

NEWLIBPATH="@executable_path/../Frameworks"

echo "Modify executable_path to libshout in IcecastSourceClient"

#echo cp ${SRCROOT}/LocalRadio/Icecast-libshout-master/src/.libs/libshout.3.dylib ${BUILT_PRODUCTS_DIR}
#cp ${SRCROOT}/LocalRadio/Icecast-libshout-master/src/.libs/libshout.3.dylib ${BUILT_PRODUCTS_DIR}

#echo codesign -f --entitlements "${SRCROOT}/IcecastSourceClient/IcecastSourceClient/IcecastSourceClient.entitlements" -s "${CODE_SIGN_IDENTITY}" ${LIBPATH}/libshout.3.dylib
#codesign -f --entitlements "${SRCROOT}/IcecastSourceClient/IcecastSourceClient/IcecastSourceClient.entitlements" -s "${CODE_SIGN_IDENTITY}" ${LIBPATH}/libshout.3.dylib

#echo install_name_tool -change @executable_path/../Frameworks/libssl.1.0.0.dylib /usr/lib/libssl.dylib ${EXECFOLDER}/icecast
#install_name_tool -change @executable_path/../Frameworks/libssl.1.0.0.dylib /usr/lib/libssl.dylib ${EXECFOLDER}/icecast

#echo install_name_tool -change @executable_path/../Frameworks/libcrypto.1.0.0.dylib /usr/lib/libcrypto.dylib ${EXECFOLDER}/icecast
#install_name_tool -change @executable_path/../Frameworks/libcrypto.1.0.0.dylib /usr/lib/libcrypto.dylib ${EXECFOLDER}/icecast



#echo install_name_tool -change @executable_path/../Frameworks/libssl.1.0.0.dylib /usr/lib/libssl.dylib ${LIBPATH}/libcurl.4.dylib
#install_name_tool -change @executable_path/../Frameworks/libssl.1.0.0.dylib /usr/lib/libssl.dylib ${LIBPATH}/libcurl.4.dylib

#echo install_name_tool -change @executable_path/../Frameworks/libcrypto.1.0.0.dylib /usr/lib/libcrypto.dylib ${LIBPATH}/libcurl.4.dylib
#install_name_tool -change @executable_path/../Frameworks/libcrypto.1.0.0.dylib /usr/lib/libcrypto.dylib ${LIBPATH}/libcurl.4.dylib




echo install_name_tool -change /usr/local/lib/libshout.3.dylib @executable_path/../Frameworks/libshout.3.dylib ${EXECFOLDER}/IcecastSourceClient
install_name_tool -change /usr/local/lib/libshout.3.dylib @executable_path/../Frameworks/libshout.3.dylib ${EXECFOLDER}/IcecastSourceClient



echo install_name_tool -id @executable_path/../Frameworks/libshout.3.dylib ${LIBPATH}/libshout.3.dylib
install_name_tool -id @executable_path/../Frameworks/libshout.3.dylib ${LIBPATH}/libshout.3.dylib




echo install_name_tool -change /opt/local/lib/libvorbis.0.dylib @executable_path/../Frameworks/libvorbis.0.dylib ${LIBPATH}/libshout.3.dylib
install_name_tool -change /opt/local/lib/libvorbis.0.dylib @executable_path/../Frameworks/libvorbis.0.dylib ${LIBPATH}/libshout.3.dylib



#echo install_name_tool -change /opt/local/lib/libssl.1.0.0.dylib @executable_path/../Frameworks/libssl.1.0.0.dylib ${LIBPATH}/libshout.3.dylib
#install_name_tool -change /opt/local/lib/libssl.1.0.0.dylib @executable_path/../Frameworks/libssl.1.0.0.dylib ${LIBPATH}/libshout.3.dylib
#echo install_name_tool -change /opt/local/lib/libcrypto.1.0.0.dylib @executable_path/../Frameworks/libcrypto.1.0.0.dylib ${LIBPATH}/libshout.3.dylib
#install_name_tool -change /opt/local/lib/libcrypto.1.0.0.dylib @executable_path/../Frameworks/libcrypto.1.0.0.dylib ${LIBPATH}/libshout.3.dylib

#echo install_name_tool -change /opt/local/lib/libssl.1.0.0.dylib @executable_path/../Frameworks/libssl.1.1.dylib ${LIBPATH}/libshout.3.dylib
#install_name_tool -change /opt/local/lib/libssl.1.0.0.dylib @executable_path/../Frameworks/libssl.1.1.dylib ${LIBPATH}/libshout.3.dylib
#echo install_name_tool -change /opt/local/lib/libcrypto.1.0.0.dylib @executable_path/../Frameworks/libcrypto.1.1.dylib ${LIBPATH}/libshout.3.dylib
#install_name_tool -change /opt/local/lib/libcrypto.1.0.0.dylib @executable_path/../Frameworks/libcrypto.1.1.dylib ${LIBPATH}/libshout.3.dylib

#echoinstall_name_tool -change @executable_path/../Frameworks/libssl.1.0.0.dylib @executable_path/../Frameworks/libssl.1.1.dylib ${LIBPATH}/libshout.3.dylib
#install_name_tool -change @executable_path/../Frameworks/libssl.1.0.0.dylib @executable_path/../Frameworks/libssl.1.1.dylib ${LIBPATH}/libshout.3.dylib
#echo install_name_tool -change @executable_path/../Frameworks/libcrypto.1.0.0.dylib @executable_path/../Frameworks/libcrypto.1.1.dylib ${LIBPATH}/libshout.3.dylib
#install_name_tool -change @executable_path/../Frameworks/libcrypto.1.0.0.dylib @executable_path/../Frameworks/libcrypto.1.1.dylib ${LIBPATH}/libshout.3.dylib


echo install_name_tool -change /opt/local/lib/libssl.1.0.0.dylib /usr/lib/libssl.dylib ${LIBPATH}/libshout.3.dylib
install_name_tool -change /opt/local/lib/libssl.1.0.0.dylib /usr/lib/libssl.dylib ${LIBPATH}/libshout.3.dylib

echo install_name_tool -change /opt/local/lib/libcrypto.1.0.0.dylib /usr/lib/libcrypto.dylib ${LIBPATH}/libshout.3.dylib
install_name_tool -change /opt/local/lib/libcrypto.1.0.0.dylib /usr/lib/libcrypto.dylib ${LIBPATH}/libshout.3.dylib



echo install_name_tool -change /opt/local/lib/libspeex.1.dylib @executable_path/../Frameworks/libspeex.1.dylib ${LIBPATH}/libshout.3.dylib
install_name_tool -change /opt/local/lib/libspeex.1.dylib @executable_path/../Frameworks/libspeex.1.dylib ${LIBPATH}/libshout.3.dylib



echo install_name_tool -change /opt/local/lib/libtheora.0.dylib @executable_path/../Frameworks/libtheora.0.dylib ${LIBPATH}/libshout.3.dylib
install_name_tool -change /opt/local/lib/libtheora.0.dylib @executable_path/../Frameworks/libtheora.0.dylib ${LIBPATH}/libshout.3.dylib



echo install_name_tool -change /opt/local/lib/libogg.0.dylib @executable_path/../Frameworks/libogg.0.dylib ${LIBPATH}/libshout.3.dylib
install_name_tool -change /opt/local/lib/libogg.0.dylib @executable_path/../Frameworks/libogg.0.dylib ${LIBPATH}/libshout.3.dylib



#echo install_name_tool -id @executable_path/../Frameworks/libssl.1.1.dylib ${LIBPATH}/libssl.1.1.dylib
#install_name_tool -id @executable_path/../Frameworks/libssl.1.1.dylib ${LIBPATH}/libssl.1.1.dylib

#echo install_name_tool -change /usr/local/lib/libcrypto.1.1.dylib @executable_path/../Frameworks/libcrypto.1.1.dylib ${LIBPATH}/libssl.1.1.dylib
#install_name_tool -change /usr/local/lib/libcrypto.1.1.dylib @executable_path/../Frameworks/libcrypto.1.1.dylib ${LIBPATH}/libssl.1.1.dylib



#echo install_name_tool -id @executable_path/../Frameworks/libcrypto.1.1.dylib ${LIBPATH}/libcrypto.1.1.dylib
#install_name_tool -id @executable_path/../Frameworks/libcrypto.1.1.dylib ${LIBPATH}/libcrypto.1.1.dylib
