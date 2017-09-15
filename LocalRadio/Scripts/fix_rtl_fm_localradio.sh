#!/bin/sh

#  fix_rtl_fm_localradio.sh
#  LocalRadio
#
#  Created by Douglas Ward on 7/17/17.
#  Copyright © 2017 ArkPhone LLC. All rights reserved.


#BUILT_PRODUCTS_DIR=/Users/dsward/Library/Developer/Xcode/DerivedData/LocalRadio-ddsodcaiskiovrbpbiioihlrnhbo/Build/Products/Debug

EXECFILE=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}
#EXECFILE=/Users/dsward/Library/Developer/Xcode/DerivedData/LocalRadio-fypfuqvcbqkwibconllscqvxdnhj/Build/Products/Debug/LocalRadio.app/Contents/MacOS/LocalRadio

LIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}
#LIBPATH=/Users/dsward/Library/Developer/Xcode/DerivedData/LocalRadio-fypfuqvcbqkwibconllscqvxdnhj/Build/Products/Debug/LocalRadio.app/Contents/Frameworks

NEWLIBPATH="@executable_path/../Frameworks"

echo install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/rtl_fm_localradio

install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/rtl_fm_localradio
