#!/bin/sh

#  codesign_tools.sh
#  LocalRadio
#
#  Created by Douglas Ward on 7/17/17.
#  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.

#  No longer used, tool project are now configured to build with an entitlements file that specifies to inherit entitlements from the host app. (com.apple.security.inherit)

#  Remove exit statement and substitute the "Mac Developer: John Doe (xxxxxxxxxx)" identity with a registered Apple developer ID
#  The commands will be generated in console, and can be pasted to terminal for execution

#  This info might be useful for code signing external tools that can be executed with LocalRadio's Custom Tools feature.

exit;

echo codesign -f --entitlements "${SRCROOT}/wfm-tools-master/stereodemux/stereodemux.entitlements" -s "Mac Developer: Developer Name (xxxxxxxxxx)" ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/stereodemux

echo codesign -f --entitlements "${SRCROOT}/rtl_fm_localradio/rtl_fm_localradio.entitlements" -s "Mac Developer: Developer Name (xxxxxxxxxx)" ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/rtl_fm_localradio

echo codesign -f --entitlements "${SRCROOT}/UDPSender/UDPSender.entitlements" -s "Mac Developer: Developer Name (xxxxxxxxxx)" ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/UDPSender

echo codesign -f --entitlements "${SRCROOT}/UDPListener/UDPListener.entitlements" -s "Mac Developer: Developer Name (xxxxxxxxxx)" ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/UDPListener

echo codesign -f --entitlements "${SRCROOT}/AudioMonitor/AudioMonitor.entitlements" -s "Mac Developer: Developer Name (xxxxxxxxxx)" ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/AudioMonitor

echo codesign -f --entitlements "${SRCROOT}/AudioMonitor2/AudioMonitor2.entitlements" -s "Mac Developer: Developer Name (xxxxxxxxxx)" ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/AudioMonitor2

echo codesign -f --entitlements "${SRCROOT}/IcecastSource/IcecastSource.entitlements" -s "Mac Developer: Developer Name (xxxxxxxxxx)" ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/IcecastSource

