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
* Icecast for AAC streaming.
* TPCircularBuffer is used for audio output with the direct audio option on the Mac, which bypasses the standard MP3 encoding and streaming buffers.
* An interface to the FCC database of U.S. FM radio stations, searchable by location and radius for easily finding local stations.

The LocalRadio application bundle is sandboxed and code-signed according to Apple's recommendations, and the extra tools inherit the entitlements of the main application when executed with NSTask and NSPipe I/O.  

Most of the open-source tools and libraries - with the notable exception of rtl\_fm\_localradio - were built with MacPorts, then the executables were copied into the Xcode project, and the install\_name\_tool was used to change the install names and rpaths to "@executable_path/../Frameworks/".

The following list of MacPorts packages must be installed to build LocalRadio in Xcode.  Use the MacPorts "sudo port install" command, which may also require automatic installation of some other package dependencies.

* automake
* autoconf
* pkgconfig
* dylibbundler
* libusb
* libiconv
* liquid-dsp
* fftw-3-single
* fftw-3
* libsndfile
* flac
* libogg
* libvorbis
* libtheora
* libopus
* opusfile
* openssl
* zlib







configure.ldflags-append -headerpad\_max\_install\_names

<hr>

Copyright (c) 2017-2019 by ArkPhone, LLC.

All trademarks are the property of their respective holders.
