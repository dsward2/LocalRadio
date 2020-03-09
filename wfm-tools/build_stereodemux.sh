#!/bin/sh

#  build_stereodemux.sh
#  LocalRadio
#
#  Created by Douglas Ward on 7/29/18.
#  Copyright © 2017-2020 ArkPhone LLC. All rights reserved.

#  Build stereodemux with MacPorts libraries libliquid and libsndfile

EXECFILE=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}

EXECFOLDER=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}

LIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}

NEWLIBPATH="@executable_path/../Frameworks"

echo "Build stereodemux"

export CPPFLAGS='-I/opt/local/include'
export LDFLAGS='-L/opt/local/lib'
export C_INCLUDE_PATH=/opt/local/include/
export CPLUS_INCLUDE_PATH=/opt/local/include/
export PATH=/opt/local/bin:$PATH
export PATH=/opt/local/sbin:$PATH

cd ${SRCROOT}/stereodemux

./autogen.sh && ./configure && make

cp stereodemux ${BUILT_PRODUCTS_DIR}
