#!/bin/sh

#  import_dylibs.sh
#  LocalRadio
#
#  Created by Douglas Ward on 5/14/17.
#  Copyright © 2017 ArkPhone LLC. All rights reserved.

# Modify MacPorts libraries for embed in application bundle

#https://github.com/auriamg/macdylibbundler
#dylibbundler -b -x ./LocalRadio.app/Contents/MacOS/LocalRadio -d ./MacPorts_Libraries/ -p @executable_path/../Frameworks/

EXECFILE=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}
#EXECFILE=/Users/dsward/Library/Developer/Xcode/DerivedData/LocalRadio-fypfuqvcbqkwibconllscqvxdnhj/Build/Products/Debug/LocalRadio.app/Contents/MacOS/LocalRadio

LIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}
#LIBPATH=/Users/dsward/Library/Developer/Xcode/DerivedData/LocalRadio-fypfuqvcbqkwibconllscqvxdnhj/Build/Products/Debug/LocalRadio/Contents/Frameworks

NEWLIBPATH="@executable_path/../Frameworks"

echo "Run dylibbundler against main app executable"
echo /opt/local/bin/dylibbundler -of -b -x "${EXECFILE}" -d "${LIBPATH}" -p "${NEWLIBPATH}"

/opt/local/bin/dylibbundler -of -b -x "${EXECFILE}" -d "${LIBPATH}" -p "${NEWLIBPATH}"
