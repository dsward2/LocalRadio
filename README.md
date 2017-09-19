# LocalRadio

### REPOSITORY UNDER CONSTRUCTION

### Test-release announcement here soon

<br><br>

<img src="https://cdn.rawgit.com/dsward2/LocalRadio/4a6a79bc/Documents/LocalRadio-poster.svg">

Project page: https://github.com/dsward2/LocalRadio

LocalRadio is an experimental, GPL-2 licensed open-source application for listening to "software defined radio" on your Mac and mobile devices.  With an inexpensive RTL-SDR device plugged into the Mac's USB port, LocalRadio provides a casual listening experience for your favorite local FM broadcasts, free music, news, sports, weather, public safety and aviation scanner monitoring, and other radio sources.  

LocalRadio's easy-to-use web interface allows the radio to be shared from a Mac to iPhones, iPads, Android devices, and other PCs on your home network.  No additional software or hardware is required for sharing with mobile devices, simply use the built-in mobile web browser to connect to LocalRadio and tune to your favorite stations.  You can also listen to LocalRadio audio on your Apple TV and other AirPlay-compatible devices.


LocalRadio does not provide features like FFT waterfalls, panadapters, or signal recording that are found on other SDR software.  For those features, GQRX for Mac is highly recommended.  GQRX is a good way to discover radio frequencies that can be used with LocalRadio.

LocalRadio is intended for use as in-home entertainment, using a local area network with a private IP address.  It has not been tested with a public IP address, particularly for security testing, therefore it is not recommended for that purpose.  For simply listening to LocalRadio on the Mac with the RTL-SDR device plugged in, no network is required at all.


# Screen captures

## LocalRadio native macOS app

<img src="Documents/Images/screen_caps/LocalRadio1.png?raw=true" width="227px">

<img src="Documents/Images/screen_caps/LocalRadio2.png?raw=true" width="227px%">

<img src="Documents/Images/screen_caps/LocalRadio3.png?raw=true" width="227px">

<img src="Documents/Images/screen_caps/scanning_status.gif?raw=true" width="229px">

<img src="Documents/Images/screen_caps/LocalRadio5.png?raw=true" width="227px">

<img src="Documents/Images/screen_caps/LocalRadio6.png?raw=true">

## LocalRadio in macOS Safari web browser

<img src="Documents/Images/screen_caps/MacSafari.png?raw=true" width="345px">

## LocalRadio in iPhone Safari web browser

<img src="Documents/Images/screen_caps/iPhone1.png?raw=true" width="311px">

<br><br>
<img src="Documents/Images/screen_caps/iPhone2.png?raw=true" width="311px">

<br><br>
<img src="Documents/Images/screen_caps/iPhone3.png?raw=true" width="311px">

<br><br>
<img src="Documents/Images/screen_caps/iPhone4.png?raw=true" width="311px">

<br><br>
<img src="Documents/Images/screen_caps/iPhone5.png?raw=true" width="311px">

<br><br>
<img src="Documents/Images/screen_caps/iPhone6.png?raw=true" width="311px">

#

# Hardware Requirements

The LocalRadio application is built for Mac OS X 10.11 or later.

An inexpensive "RTL-SDR" USB device with the Realtek RTL2832U chip and a suitable antenna are required.  A variety of those devices are available from Amazon and other online stores.

LocalRadio has been tested with the "RTL-SDR.com v3" device.  It is well-designed and supports all of the features of LocalRadio, including direct sampling "Q-branch" mode to receive AM and shortwave frequencies.  This device - and an excellent blog - are available at [https://rtl-sdr.com]().  

Other RTL-SDR devices have not been tested yet.  Unlike the RTL-SDR.com device, many other device brands will only operate on higher frequencies, which may be adequate for FM broadcasts, NOAA weather radio, aviation and public service bands.  It may be possible to modify those devices to receive lower frequencies.

To minimize electrical interference and improve radio reception, it may be helpful to use an "active USB" cable to allow the antenna and RTL-SDR device to be placed away from the computer.

**If you decide to use an outdoor antenna with RTL-SDR, be aware of the risk of damage to your equipment from lightning storms.  Disconnect the outdoor antenna from your computer during thunderstorms, or whenever it is not in use.  An indoor antenna is the safer option for a permanent antenna connection.**

# Application Notes

Currently, LocalRadio does not play FM stereo audio.  LocalRadio can receive FM stereo stations, but they will be played as monophonic audio.  A future release of LocalRadio may support stereo, either by modifying the rtl_fm_localradio source, or by using a different tool.

LocalRadio supports multiple devices by using a built-in LAME MP3 encoder, EZStream and Icecast server.  Due to the buffering required to process the audio through compression and streaming, there is typically a delay of ten seconds between the radio signal and the audio output.  On the Mac running LocalRadio, that delay can be removed temporarily by removing the checkmark for "Use Web View Player".

If you like LocalRadio, please click the "Star" button on this GitHub project, and check out my other app on GitHub, macSVG.

### Check Your Audio

LocalRadio uses the Sox audio processing tool for various tasks, and the user can configure Sox filters for the audio streaming output.  For example, if the filter is set to "vol 1", the streaming audio will play at the default value.  Setting the Sox filter to "vol 2" will play the audio louder.  The "vol 0.5" will decrease the streaming audio volume.

Sox filter effects can be configured as a "processing chain".  For broadcast FM frequencies stored as LocalRadio Favorites, the default configuration is "vol 1 deemph dither -s".  Other common filter effects are bass, treble, lowpass, highpass, and many others.  See the Sox filters page for more filter options, under the "EFFECTS" heading: 

[http://sox.sourceforge.net/sox.html#EFFECTS](http://sox.sourceforge.net/sox.html#EFFECTS)

Currently, the Sox filter is a plain text representation, and LocalRadio does not evaluate the Sox audio filter for correctness, so the user must be careful to enter a valid configuration.  

Due to the various factors that can affect the final output volume, be cautious when tuning to a new frequency.  When using the "vol" filter, start with a low value, then adjust accordingly.  

It is also recommended to start with the the Apple system audio volume turned down, or turn down the volume knobs on your speakers.  If you are tuned to the aviation band, and a nearby airplane starts transmitting, the audio can suddenly become extremely loud and distorted compared to distant airplanes on the same frequency. 


### Folder Name Bug

If the LocalRadio application is contained within a folder with a space chracter in the folder name - like "~/Untitled Folder/LocalRadio.app" - LocalRadio will display an alert window and prompt the user to click a Quit button to terminate the application.

In that situation, the problem can be resolved (hopefully) by removing all space characters in the folder name, then launching the LocalRadio app again.

Specifically, for an undetermined reason, LocalRadio cannot launch the built-in "AudioMonitor" tool as an NSTask in a code-signed app extracted from an Xcode Archive if the application path contains a space. Prefixing backslashes before spaces in the path did not help.  The error message in Console.log says "launch path not accessible".

Copyright (c) 2017 by ArkPhone, LLC.

All trademarks are the property of their respective holders.
