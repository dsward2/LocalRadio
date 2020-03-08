#!/bin/sh

#  fix_StreamingServer.sh
#  LocalRadio
#
#  Created by Douglas Ward on 2/18/20.
#  Copyright © 2020 ArkPhone LLC. All rights reserved.

#  Fix GCDWebServers.framework to load properly for StreamingServer

exit;

EXECFILE=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}

EXECFOLDER=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}

LIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}

NEWLIBPATH="@executable_path/../Frameworks"

echo "Modify executable_path to GCDWebServers.framework in StreamingServer"

echo install_name_tool -change @rpath/GCDWebServers.framework/Versions/A/GCDWebServers @executable_path/../Frameworks/GCDWebServers.framework/Versions/A/GCDWebServers ${EXECFOLDER}/StreamingServer

install_name_tool -change @rpath/GCDWebServers.framework/Versions/A/GCDWebServers @executable_path/../Frameworks/GCDWebServers.framework/Versions/A/GCDWebServers ${EXECFOLDER}/StreamingServer

