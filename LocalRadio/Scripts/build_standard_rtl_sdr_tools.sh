#!/bin/sh

exit;   # omit rtl_sdr tools for now

# echo SRCROOT = ${SRCROOT}

# modify runtime PATH environment to find MacPorts tools first, particularily the cmake tools
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"

RTLSDRSRC=${SRCROOT}/LocalRadio/rtl-sdr-master
echo Make RTL-SDR at ${RTLSDRSRC}

RTLSDRBLD=${RTLSDRSRC}/build
RTLSDRPRD=${RTLSDRBLD}/src
mkdir -p "${RTLSDRBLD}"
cd "${RTLSDRBLD}"
cmake ../
make

LIBPATH=${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}
EXECPATH=${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}

mv ${RTLSDRPRD}/librtlsdr.0.5git.dylib ${RTLSDRPRD}/librtlsdr.0.dylib

install_name_tool -id @executable_path/../Frameworks/librtlsdr.0.dylib ${RTLSDRPRD}/librtlsdr.0.dylib
install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${RTLSDRPRD}/librtlsdr.0.dylib

install_name_tool -change ${RTLSDRPRD}/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${RTLSDRPRD}/rtl_adsb
install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${RTLSDRPRD}/rtl_adsb

install_name_tool -change ${RTLSDRPRD}/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${RTLSDRPRD}/rtl_adsb
install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${RTLSDRPRD}/rtl_adsb

install_name_tool -change ${RTLSDRPRD}/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${RTLSDRPRD}/rtl_eeprom
install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${RTLSDRPRD}/rtl_eeprom

install_name_tool -change ${RTLSDRPRD}/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${RTLSDRPRD}/rtl_fm
install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${RTLSDRPRD}/rtl_fm

install_name_tool -change ${RTLSDRPRD}/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${RTLSDRPRD}/rtl_power
install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${RTLSDRPRD}/rtl_power

install_name_tool -change ${RTLSDRPRD}/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${RTLSDRPRD}/rtl_sdr
install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${RTLSDRPRD}/rtl_sdr

install_name_tool -change ${RTLSDRPRD}/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${RTLSDRPRD}/rtl_tcp
install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${RTLSDRPRD}/rtl_tcp

install_name_tool -change ${RTLSDRPRD}/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${RTLSDRPRD}/rtl_test
install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${RTLSDRPRD}/rtl_test



#install_name_tool -change ${RTLSDRPRD}/librtlsdr.0.dylib @executable_path/../Frameworks/librtlsdr.0.dylib ${RTLSDRPRD}/rtl_fm_localradio
#install_name_tool -change /usr/local/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/../Frameworks/libusb-1.0.0.dylib ${RTLSDRPRD}/rtl_fm_localradio
