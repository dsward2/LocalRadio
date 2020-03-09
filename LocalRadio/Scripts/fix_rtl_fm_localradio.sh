#!/bin/sh

#  fix_rtl_fm_localradio.sh
#  LocalRadio
#
#  Created by Douglas Ward on 7/17/17.
#  Copyright © 2017-2020/Volumes/Mercury/Users/dsward/Documents/ArkPhone_LLC_Projects/LocalRadio/LocalRadio/Scripts/fix_rtl_fm_localradio.sh:#  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.8 ArkPhone LLC. All rights reserved.

#  Fix libusb to load properly for rtl_str_localradio

EXECFILE=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}

LIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}

NEWLIBPATH="@executable_path/../Frameworks"

echo "Modify executable_path to libusb in rtl_fm_localradio"

echo install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_fm_localradio

install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_fm_localradio

exit

# moved to import_dylibs2.sh
echo "Modify executable_path to libltdl in sox and libsox.3.dylib"

echo install_name_tool -change /usr/local/opt/libtool/lib/libltdl.7.dylib @executable_path/../Frameworks/libltdl.7.dylib ${BUILT_PRODUCTS_DIR}/sox

install_name_tool -change /usr/local/opt/libtool/lib/libltdl.7.dylib @executable_path/../Frameworks/libltdl.7.dylib ${BUILT_PRODUCTS_DIR}/sox

echo install_name_tool -change /usr/local/opt/libtool/lib/libltdl.7.dylib @executable_path/../Frameworks/libltdl.7.dylib ${BUILT_PRODUCTS_DIR}/Libraries_Modified/libsox.3.dylib

install_name_tool -change /usr/local/opt/libtool/lib/libltdl.7.dylib @executable_path/../Frameworks/libltdl.7.dylib ${BUILT_PRODUCTS_DIR}/Libraries_Modified/libsox.3.dylib
