#!/bin/sh

#  fix_rtl_fm_localradio.sh
#  LocalRadio
#
#  Created by Douglas Ward on 7/17/17.
#  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.

#  Fix libusb to load properly for rtl_str_localradio

EXECFILE=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}

LIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}

NEWLIBPATH="@executable_path/../Frameworks"

echo "Modify executable_path to libusb in rtl_fm_localradio"

echo install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_fm_localradio

install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_fm_localradio
