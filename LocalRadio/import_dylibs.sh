#!/bin/sh

#  import_dylibs.sh
#  SDR_Server
#
#  Created by Douglas Ward on 5/14/17.
#  Copyright © 2017 ArkPhone LLC. All rights reserved.

dylibbundler -b -x ./SDR_Server.app/Contents/MacOS/SDR_Server -d ./SDR_Server.app/Contents/Frameworks/ -p @executable_path/../Frameworks/
