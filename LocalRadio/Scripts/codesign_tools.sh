#!/bin/sh

#  codesign_tools.sh
#  LocalRadio
#
#  Created by Douglas Ward on 7/17/17.
#  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.

#  Remove exit statement and substitute the "Mac Developer: John Doe (xxxxxxxxxx)" identity with a registered Apple developer ID

exit;

echo codesign -f --entitlements "${SRCROOT}/rtl_fm_localradio/rtl_fm_localradio.entitlements" -s "Mac Developer: Developer Name (xxxxxxxxxx)" ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/rtl_fm_localradio

echo codesign -f --entitlements "${SRCROOT}/UDPSender/UDPSender.entitlements" -s "Mac Developer: Developer Name (xxxxxxxxxx)" ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/UDPSender

echo codesign -f --entitlements "${SRCROOT}/UDPListener/UDPListener.entitlements" -s "Mac Developer: Developer Name (xxxxxxxxxx)" ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/UDPListener

echo codesign -f --entitlements "${SRCROOT}/AudioMonitor/AudioMonitor.entitlements" -s "Mac Developer: Developer Name (xxxxxxxxxx)" ${BUILT_PRODUCTS_DIR}/LocalRadio.app/Contents/MacOS/AudioMonitor

