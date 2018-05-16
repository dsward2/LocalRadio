# LocalRadio
## Application Notes

LocalRadio does not provide features like FFT waterfalls, panadapters, or signal recording that are found on other SDR software.  For those features, GQRX for Mac is highly recommended.  GQRX is a good way to discover radio frequencies that can be used with LocalRadio. GQRX is available at [http://gqrx.dk](http://gqrx.dk)

Currently, LocalRadio does not play FM stereo audio.  LocalRadio can receive FM stereo stations, but they will be played as monophonic audio.  A future release of LocalRadio may support stereo, either by modifying the rtl_fm_localradio source, or by using a different tool.

LocalRadio supports multiple devices by using a built-in LAME MP3 encoder, EZStream and Icecast server.  Due to the buffering required to process the audio through compression and streaming, there is typically a delay of ten seconds between the radio signal and the audio output.  On the Mac running LocalRadio, that delay can be removed temporarily by removing the checkmark for "Use Web View Player".

If you like LocalRadio, please click the "Star" button on this GitHub project, and check out my other app on GitHub, macSVG.

### Check Your Audio

LocalRadio uses the Sox audio processing tool for various tasks, and the user can configure Sox filters for the audio streaming output.  For example, if the filter is set to "vol 1", the streaming audio will play at the default value.  Setting the Sox filter to "vol 2" will play the audio louder.  The "vol 0.5" will decrease the streaming audio volume.

Sox filter effects can be configured as a "processing chain".  For broadcast FM frequencies stored as LocalRadio Favorites, the default configuration is "vol 1 deemph dither -s".  Other common filter effects are bass, treble, lowpass, highpass, and many others.  See the Sox filters page for more filter options, under the "EFFECTS" heading: 

[http://sox.sourceforge.net/sox.html#EFFECTS](http://sox.sourceforge.net/sox.html#EFFECTS)

Currently, the Sox filter is a plain text representation, and LocalRadio does not evaluate the Sox audio filter for correctness, so the user must be careful to enter a valid configuration.  

Do not use the Sox "rate" effect.  LocalRadio always sets the rate value to 48000, then adds the Sox effects you specify to the audio processing chain.

Due to the various factors that can affect the final output volume, be cautious when tuning to a new frequency.  When using the "vol" filter, start with a low value, then adjust accordingly.  

It is also recommended to start with the the Apple system audio volume turned down, or turn down the volume knobs on your speakers.  If you are tuned to the aviation band, and a nearby airplane starts transmitting, the audio can suddenly become extremely loud and distorted compared to distant airplanes on the same frequency. 


### Folder Name Bug

If the LocalRadio application is contained within a folder with a space chracter in the folder name - like "~/Untitled Folder/LocalRadio.app" - LocalRadio will display an alert window and prompt the user to click a Quit button to terminate the application.

In that situation, the problem can be resolved (hopefully) by removing all space characters in the folder name, then launching the LocalRadio app again.

Specifically, for an undetermined reason, LocalRadio cannot launch the built-in "AudioMonitor" tool as an NSTask in a code-signed app extracted from an Xcode Archive if the application path contains a space. Prefixing backslashes before spaces in the path did not help.  The error message in Console.log says "launch path not accessible".

<hr>

Copyright (c) 2017-2018 by ArkPhone, LLC.

All trademarks are the property of their respective holders.
