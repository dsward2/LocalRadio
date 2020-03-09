#!/bin/sh

#  fix_stereodemux.sh
#  LocalRadio
#
#  Created by Douglas Ward on 7/28/18.
#  Copyright © 2017-2020 ArkPhone LLC. All rights reserved.

#  Fix libliquid and libsndfile dylibs to load properly for stereodemux

EXECFILE=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}

EXECFOLDER=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}

LIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}

NEWLIBPATH="@executable_path/../Frameworks"

echo "Modify executable_path to libliquid and libsndfile in stereodemux"

echo install_name_tool -change /opt/local/lib/libliquid.dylib @executable_path/../Frameworks/libliquid.dylib ${EXECFOLDER}/stereodemux

install_name_tool -change /opt/local/lib/libliquid.dylib @executable_path/../Frameworks/libliquid.dylib ${EXECFOLDER}/stereodemux




echo install_name_tool -change /opt/local/lib/libsndfile.1.dylib @executable_path/../Frameworks/libsndfile.1.dylib ${EXECFOLDER}/stereodemux

install_name_tool -change /opt/local/lib/libsndfile.1.dylib @executable_path/../Frameworks/libsndfile.1.dylib ${EXECFOLDER}/stereodemux


