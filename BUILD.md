# LocalRadio - Build Notes

See README.md for general information about the LocalRadio app for macOS, or visit the project page at:

[https://github.com/dsward2/LocalRadio]()

For best results, please read this BUILD.md document with a markdown viewer application like MacDown or Xcode 9, instead of a plain text viewer.

LocalRadio combines several open-source tools into a self-contained application bundle for easy installation and use. Here are some of the major components -

* The Osmocom RTL-SDR software suite.
* A modified version of Kyle Keen's branch of the popular rtl\_fm command-line tool.  LocalRadio provides a graphical user interface for controlling most of the rtl\_fm settings.  Some new features were added, like a live display of signal strength that is helpful for fine-tuning the squlch level for scanner functions.
* The CocoaHTTPServer for the web interface.
* CocoaAsyncSocket for interprocess communications.
* The Skeleton HTML framework.
* The SQLite database manager for storing frequency and category data.
* SQLiteLibrary is an Objective-C interface for using SQLite.
* WebKit for the Mac application's user interface.
* The Sox and LAME tools for audio resampling, filtering, MP3 encoding and output.
* Icecast and EZStream for MP3 streaming.
* TPCircularBuffer is used for audio output with the direct audio option on the Mac, which bypasses the standard MP3 encoding and streaming buffers.
* An interface to the FCC database of U.S. FM radio stations, searchable by location and radius for easily finding local stations.

The LocalRadio application bundle is sandboxed and code-signed according to Apple's recommendations, and the extra tools inherit the entitlements of the main application when executed with NSTask and NSPipe I/O.  

Most of the open-source tools and libraries - with the notable exception of rtl\_fm\_localradio - were built with MacPorts, then the executables were copied into the Xcode project, and the install\_name\_tool was used to change the install names and rpaths to "@executable_path/../Frameworks/".

The following MacPorts packages must be installed to build LocalRadio in Xcode:

* sudo port install libusb
* sudo port install rtl-sdr

Those installations will automatically require these dependencies to  be installed: 

* bison
* bison-runtime
* bzip2
* cmake
* curl
* curl-ca-bundle
* doxygen
* expat
* flex
* gettext
* libarchive
* libiconv
* libpng
* libuv
* libxml2
* lz4
* lzo2
* m4
* ncurses
* openssl
* pkgconfig
* xz
* zlib

Those dependencies will generate several libraries required by LocalRadio.  In order to distribute LocalRadio as a self-contained application, these dylibs are copied from MacPorts into the Xcode project, modified with install\_name\_tool, then copied at build time into the application bundle at LocalRadio.app/Contents/Frameworks:

* libcrypto.1.0.0.dylib
* libcurl.4.dylib
* libev.4.dylib
* libFLAC.8.dylib
* libiconv.2.dylib
* libid3tag.0.3.0.dylib
* liblzma.5.dylib
* libmad.0.dylib
* libmagic.1.dylib
* libmp3lame.0.dylib
* libncurses.6.dylib
* libogg.0.dylib
* libopencore-amrnb.0.dylib
* libopencore-amrwb.0.dylib
* libopus.0.dylib
* libopusfile.0.dylib
* libpng16.16.dylib
* libreadline.7.0.dylib
* librtlsdr.0.dylib
* libshout.3.dylib
* libsndfile.1.dylib
* libsox.3.dylib
* libspeex.1.dylib
* libsqlite3.0.dylib
* libssl.1.0.0.dylib
* libtag_c.0.0.0.dylib
* libtag.1.17.0.dylib
* libtheora.0.dylib
* libtwolame.0.dylib
* libusb-1.0.0.dylib
* libvorbis.0.dylib
* libvorbisenc.2.dylib
* libvorbisfile.3.dylib
* libwavpack.1.dylib
* libxml2.2.dylib
* libxslt.1.dylib
* libz.1.2.11.dylib

Similarly, these tools are copied from MacPorts, modified with install\_name\_tool, then copied to LocalRadio.app/Contents/MacOS at build time -

* ezstream
* icecast
* lame
* rtl\_adsb
* rtl\_eeprom
* rtl\_fm
* rtl\_power
* rtl\_sdr
* rtl\_tcp
* rtl\_test
* socat
* sox

The libssl and libcrypto libraries from MacPorts were patched and relinked to fix a problem with using install\_name\_tool, which failed due to a lack of space in the object file for the renamed rpaths.  Those modules should be relinked with this line added to /usr/local/ports/security/openssl/Portfile :

configure.ldflags-append -headerpad\_max\_install\_names

<hr>

Copyright (c) 2017-2018 by ArkPhone, LLC.

All trademarks are the property of their respective holders.
