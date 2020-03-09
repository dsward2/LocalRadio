# LocalRadio - Build Notes

See README.md for general information about the LocalRadio app for macOS, or visit the project page at:

[https://github.com/dsward2/LocalRadio]()

Clone the LocalRadio project with this procedure -

Launch Xcode and click on the "Clone an existing project" command in the Welcome to Xcode window.
Enter this URL for the repository: https://github.com/dsward/LocalRadio
Save the project to your disk drive.
Inspect the downloaded project folder and verify that the ".git" file was included.  If the project was downloaded as a ZIP file, it was not cloned and the .git file will be missing.

Open the LocalRadio.xcodeproj file to view the entire project, which contains several subprojects.

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
* TPCircularBuffer is used for audio output with the direct audio option on the Mac, which bypasses the standard MP3 encoding and streaming buffers.
* An interface to the FCC database of U.S. FM radio stations, searchable by location and radius for easily finding local stations.

The LocalRadio application bundle is sandboxed and code-signed according to Apple's recommendations, and the extra tools inherit the entitlements of the main application when executed with NSTask and NSPipe I/O.  

Most of the open-source tools and libraries - with the notable exception of rtl\_fm\_localradio - were built with MacPorts, then the executables were copied into the Xcode project, and the install\_name\_tool was used to change the install names and rpaths to "@executable_path/../Frameworks/".

The following list of MacPorts packages must be installed to build LocalRadio in Xcode.  Use the MacPorts "sudo port install" command, which may also trigger the automatic installation of some other package dependencies.

* automake
* autoconf
* dylibbundler
* liquid-dsp
* fftw-3
* fftw-3-single
• gettext
* libiconv
* flac
• libfec
* libogg
* libvorbis
* libsndfile
• libtool
• libusb
* ncurses
• pkgconfig
• rtl-sdr

Since MacPorts packages are constantly changing, it is possible that other files may be required that are not included in this list.

Before using the XCode Build command for the LocalRadio scheme, the sox tool must be built by using Terminal.app.  See the file named "sox git and build notes.txt" for instructions.

Note: If a build fails due to missing MacPorts tools or libraries, after adding the missing files with the "port" commands, it is recommend to use the XCode command to "Clean Build Folder..." before attempting to build again.

Note: if install_name_tool fails because there is not enough room to write the library paths in tools from MacPorts, this MacPorts configuration option can help:
configure.ldflags-append -headerpad\_max\_install\_names

<hr>

Copyright (c) 2017-2020 by ArkPhone, LLC.

All trademarks are the property of their respective holders.
