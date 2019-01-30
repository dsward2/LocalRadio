#!/bin/sh

LIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}
EXECPATH=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}

echo cp /opt/local/bin/rtl_adsb ${BUILT_PRODUCTS_DIR}
cp /opt/local/bin/rtl_adsb ${BUILT_PRODUCTS_DIR}
echo install_name_tool -change /opt/local/lib/librtlsdr.0.6git.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_adsb
install_name_tool -change /opt/local/lib/librtlsdr.0.6git.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_adsb
echo install_name_tool -change /opt/local/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_adsb
install_name_tool -change /opt/local/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_adsb

echo cp /opt/local/bin/rtl_eeprom ${BUILT_PRODUCTS_DIR}
cp /opt/local/bin/rtl_eeprom ${BUILT_PRODUCTS_DIR}
echo install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_eeprom
install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_eeprom
echo install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_eeprom
install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_eeprom

echo cp /opt/local/bin/rtl_fm ${BUILT_PRODUCTS_DIR}
cp /opt/local/bin/rtl_fm ${BUILT_PRODUCTS_DIR}
echo install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_fm
install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_fm
echo install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_fm
install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_fm

echo cp /opt/local/bin/rtl_power ${BUILT_PRODUCTS_DIR}
cp /opt/local/bin/rtl_power ${BUILT_PRODUCTS_DIR}
echo install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_power
install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_power
echo install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_power
install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_power

echo cp /opt/local/bin/rtl_sdr ${BUILT_PRODUCTS_DIR}
cp /opt/local/bin/rtl_sdr ${BUILT_PRODUCTS_DIR}
echo install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_sdr
install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_sdr
echo install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_sdr
install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_sdr

echo cp /opt/local/bin/rtl_tcp ${BUILT_PRODUCTS_DIR}
cp /opt/local/bin/rtl_tcp ${BUILT_PRODUCTS_DIR}
echo install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_tcp
install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_tcp
echo install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_tcp
install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_tcp

echo cp /opt/local/bin/rtl_test ${BUILT_PRODUCTS_DIR}
cp /opt/local/bin/rtl_test ${BUILT_PRODUCTS_DIR}
echo install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_test
install_name_tool -change /opt/local/lib/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_test
echo install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_test
install_name_tool -change /opt/local/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${BUILT_PRODUCTS_DIR}/rtl_test
