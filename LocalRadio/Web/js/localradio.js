



/*
function resizeContentFrame(aWindow) {
    console.log("resizeContentFrame");
    var contentFrameDiv = parent.document.getElementById("content_frame");
    var contentDiv = contentFrameDiv.children[0];
    contentDiv.style.visibility = 'hidden';
    contentDiv.style.height = "100px";
    var body = document.body;
    var html = document.documentElement;
    var height = Math.max( body.scrollHeight, body.offsetHeight, 
        html.clientHeight, html.scrollHeight, html.offsetHeight );
    contentDiv.style.height = (height + 100) + "px";
    contentDiv.style.top = 0;
    contentDiv.style.visibility = 'visible';
}
*/


function handleEditCategoryClick(checkbox) {
    var checkboxState = checkbox.checked;
    var getUrl = window.location;
    //var baseUrl = getUrl .protocol + "//" + getUrl.host + "/" + getUrl.pathname.split('/')[1];
    var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
    
    var cat_id = checkbox.getAttribute("cat_id");
    var freq_id = checkbox.getAttribute("freq_id");
    
    var editUrl = baseUrl + "editcategoryitem.html?cat_id=" + cat_id + "&freq_id=" + freq_id + "&is_member=" + checkboxState;
  
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
           // see xhttp.responseText;
        }
    };
    xhttp.open("GET", editUrl, true);
    xhttp.send();
}


function storeFrequencyRecord (form) {
  var formArray = $(form).serializeArray();
  var jsonData = JSON.stringify(formArray);

  var getUrl = window.location;
  var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
  var storeFrequencyUrl = baseUrl + "storefrequency.html";

  sendHTTPPostRequest("frequency", storeFrequencyUrl, jsonData, 1, true, true);
 
  return false;
};




function deleteFrequencyRecord (form) {
  var formArray = $(form).serializeArray();
  var jsonData = JSON.stringify(formArray);

  var getUrl = window.location;
  var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
  var deleteFrequencyUrl = baseUrl + "deletefrequency.html";

  var frequencyName = document.getElementById('frequency_name').value

  var r = confirm("Delete \""+frequencyName+"\" frequency?");
  if (r == true) {
    // OK button pressed
  } else {
    // Cancel button pressed
    return;
  }

  sendHTTPPostRequest("frequency", deleteFrequencyUrl, jsonData, 3, false, false);
  
  window.topButtonClicked(self);
}




function storeCategoryRecord (form) {
  var formArray = $(form).serializeArray();
  var jsonData = JSON.stringify(formArray);

  var getUrl = window.location;
  var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
  var storeCategoryUrl = baseUrl + "storecategory.html";


  sendHTTPPostRequest("category", storeCategoryUrl, jsonData, 1, true, true);
 
  return false;
};




function addCategoryRecord (form) {
  var newCategoryName = form.category_name.value;
  
  if (newCategoryName > "")
  {
      var formArray = $(form).serializeArray();
      var jsonData = JSON.stringify(formArray);

      var getUrl = window.location;
      var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
      var addCategoryUrl = baseUrl + "addcategory.html";

      sendHTTPPostRequest("category", addCategoryUrl, jsonData, 1, true, true);
  }
  else
  {
    alert("The Category Name is missing.  The new category record was not created.");
  }
 
  return false;
};


function deleteCategoryRecord (form) {
  var formArray = $(form).serializeArray();
  var jsonData = JSON.stringify(formArray);

  var getUrl = window.location;
  var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
  var deleteCategoryUrl = baseUrl + "deletecategory.html";

  var categoryName = document.getElementById('category_name').value

  var r = confirm("Delete \""+categoryName+"\" category?");
  if (r == true) {
    // OK button pressed
  } else {
    // Cancel button pressed
    return;
  }

  sendHTTPPostRequest("category", deleteCategoryUrl, jsonData, 2, false, false);
}





function insertNewFrequencyRecord (form) {
    var formArray = $(form).serializeArray();
    var jsonData = JSON.stringify(formArray);
    var validationResult = validateDataRecord("frequency", jsonData);
    if (validationResult == "OK")
    {
        var getUrl = window.location;
        var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
        var url = baseUrl + "insertnewfrequency.html";

        var xhttp = new XMLHttpRequest();
        xhttp.onreadystatechange = function() {
            if (this.readyState == 4 && this.status == 200) {
               // see xhttp.responseText;
               alert("Changes have been saved.");
               
               window.stop();
               window.backButtonClicked(self);
            }
        };
        xhttp.open("POST", url, true);
        xhttp.send(jsonData);
    }
    else
    {
        validationResult += " Changes were not saved.";
        alert(validationResult);
    }

    return false;
};


function setSampleRateInput(newSampleRate)
{
    var sampleRateInput = document.getElementById("sample_rate");
    sampleRateInput.value = newSampleRate;
}

function setScanSampleRateInput(newSampleRate)
{
    var sampleRateInput = document.getElementById("scan_sample_rate");
    sampleRateInput.value = newSampleRate;
}



function sendHTTPPostRequest (table, url, jsonData, backCount, validateData, showAlert) {
    var validationResult = "OK";
    if (validateData == true)
    {
        validationResult = validateDataRecord(table, jsonData);
    }
    if (validationResult == "OK")
    {
        var xhttp = new XMLHttpRequest();
        xhttp.onreadystatechange = function() {
            if (this.readyState == 4 && this.status == 200) {
               // see xhttp.responseText;
               if (showAlert == true)
               {
                    alert("Changes have been saved.");
               }
               
               if (backCount > 0)
               {
                    window.stop();

                    if (backCount == 1)
                    {
                        window.backButtonClicked();
                    }
                    else
                    {
                        window.topButtonClicked();
                    }
               }
            }
        };
        xhttp.open("POST", url, true);
        xhttp.send(jsonData);
    }
    else
    {
        validationResult += " Changes were not saved.";
        alert(validationResult);
    }
};


function validateDataRecord(table, jsonData)
{
    var result = "OK";
    
    if (table == "frequency")
    {
        result = validateFrequencyRecord(jsonData);
    }
    else if (table == "category")
    {
        result = validateFrequencyRecord(jsonData);
    }
    
    return result;
}



function validateFrequencyRecord(jsonData)
{
    var result = "OK";

    try
    {
        var obj = JSON.parse(jsonData);

        var frequencyRecord = [];

        for (var i = 0, len = obj.length; i < len; i++) {
            var aName = obj[i].name;
            var aValue = obj[i].value;
            
            frequencyRecord[aName] = aValue;
        }

        var station_name = frequencyRecord["station_name"];
        if (station_name == "")
        {
            return "Station Name is missing.";
        }

        var frequency = frequencyRecord["frequency"];
        if ((frequency == "") || (frequency == 0))
        {
            return "Frequency is missing or zero.";
        }

        var frequencyMode = frequencyRecord["frequency_mode"];
        if (frequencyMode == "frequency_mode_single")
        {
        }
        else if (frequencyMode == "frequency_mode_range")
        {
            var frequencyScanEnd = frequencyRecord["frequency_scan_end"];
            if ((frequencyScanEnd == "") || (frequencyScanEnd <= 0))
            {
                return "Frequency Scan End is missing or zero.  A valid end frequency is required when using Frequency Range scanner mode.";
            }

            var frequencyScanInterval = frequencyRecord["frequency_scan_interval"];
            if ((frequencyScanInterval == "") || (frequencyScanInterval <= 0))
            {
                return "Frequency Scan Interval is missing or zero.  A valid interval is required when using Frequency Range scanner mode.";
            }
        }

        var sampleRate = frequencyRecord["sample_rate"];
        if ((sampleRate == "") || (sampleRate == 0))
        {
            return "Sample Rate is missing or zero.";
        }

      
    } catch (ex) {
      //console.error(ex);
      console.log(ex);
    }
    
    return result;
}



function validateCategoryRecord(jsonData)
{
    var result = "OK";
    
    return result;
}




var frequency_min = 0;
var frequency_max = 1766000000; // 1.766 GHz


function tunerDigitClicked(element)
{
    //console.log("tunerDigitClicked: " + element.id);
    
    var tunerDigitsDiv = document.getElementById("tuner-digits")
    var tunerDigitsArray = document.getElementsByClassName("tuner-digit");
    var i;
    for (i = 0; i < tunerDigitsArray.length; i++) {
        tunerDigitsArray[i].style.backgroundColor = "white";
        tunerDigitsArray[i].selected = false;
    }
    
    element.style.backgroundColor = "lightgray";
    element.selected = true;
}




function frequencyUpButtonClicked(element)
{
    //console.log("frequencyUpButtonClicked: " + element.id);
    
    var selectedDigit = -1;
    
    var tunerDigitsDiv = document.getElementById("tuner-digits")
    var tunerDigitsArray = document.getElementsByClassName("tuner-digit");
    var i;
    for (i = 0; i < tunerDigitsArray.length; i++) {
        if (tunerDigitsArray[i].selected == true)
        {
            selectedDigit = tunerDigitsArray[i];
            
            var digitID = selectedDigit.id;
            
            /*
            var digitText = selectedDigit.innerText;
            digitText = Number(digitText) + 1;
            
            if (digitText > 9)
            {
                digitText = 9;
            }

            selectedDigit.innerText = digitText;
            */
            
            var increment = 1;
            
            switch (digitID) {
                case "XXXX-MHz":
                    increment = 1000000000;
                    break;
                case "XXX-MHz":
                    increment = 100000000;
                    break;
                case "XX-MHz":
                    increment = 10000000;
                    break;
                case "X-MHz":
                    increment = 1000000;
                    break;
                case "X-KHz":
                    increment = 100000;
                    break;
                case "XX-KHz":
                    increment = 10000;
                    break;
                case "XXX-KHz":
                    increment = 1000;
                    break;
                case "XXXX-KHz":
                    increment = 100;
                    break;
                case "XXXXX-KHz":
                    increment = 10;
                    break;
                case "XXXXXX-KHz":
                    increment = 1;
                    break;
            }
            

            var xxxxMHz = Number(document.getElementById("XXXX-MHz").innerText);
            var xxxMHz = Number(document.getElementById("XXX-MHz").innerText);
            var xxMHz = Number(document.getElementById("XX-MHz").innerText);
            var xMHz = Number(document.getElementById("X-MHz").innerText);
            var xKHz = Number(document.getElementById("X-KHz").innerText);
            var xxKHz = Number(document.getElementById("XX-KHz").innerText);
            var xxxKHz = Number(document.getElementById("XXX-KHz").innerText);
            var xxxxKHz = Number(document.getElementById("XXXX-KHz").innerText);
            var xxxxxKHz = Number(document.getElementById("XXXXX-KHz").innerText);
            var xxxxxxKHz = Number(document.getElementById("XXXXXX-KHz").innerText);
            
            var oldFrequency = (
                    (xxxxMHz *  1000000000) +
                    (xxxMHz *   100000000) +
                    (xxMHz *    10000000) +
                    (xMHz *     1000000) +
                    (xKHz *     100000) +
                    (xxKHz *    10000) +
                    (xxxKHz *   1000) +
                    (xxxxKHz *  100) +
                    (xxxxxKHz * 10) +
                     xxxxxxKHz);
            
            if ((oldFrequency >= 87500000) && (oldFrequency <= 107900000))
            {
                if (digitID == "X-KHz")
                {
                    if (xKHz % 2 == 1)
                    {
                        increment = 200000;  // special rule for FM broadcast - odd values only for 100x KHz
                    }
                }
            }

            var newFrequency = oldFrequency + increment;
            
            setFrequencyDigits(newFrequency);
            
            break;
        }
    }
    
    checkFrequencyRange();
    
    updateFrequencyInput();
}


function frequencyDownButtonClicked(element)
{
    //console.log("frequencyDownButtonClicked: " + element.id);
    
    var selectedDigit = -1;
    
    var tunerDigitsDiv = document.getElementById("tuner-digits")
    var tunerDigitsArray = document.getElementsByClassName("tuner-digit");
    var i;
    for (i = 0; i < tunerDigitsArray.length; i++) {
        if (tunerDigitsArray[i].selected == true)
        {
            selectedDigit = tunerDigitsArray[i];

            var digitID = selectedDigit.id;

            /*
            var digitText = selectedDigit.innerText;
            digitText = Number(digitText) - 1;
            
            if (digitText < 0)
            {
              digitText = 0;
            }
            
            selectedDigit.innerText = digitText;
            */

            var increment = 1;
            
            switch (digitID) {
                case "XXXX-MHz":
                    increment = 1000000000;
                    break;
                case "XXX-MHz":
                    increment = 100000000;
                    break;
                case "XX-MHz":
                    increment = 10000000;
                    break;
                case "X-MHz":
                    increment = 1000000;
                    break;
                case "X-KHz":
                    increment = 100000;
                    break;
                case "XX-KHz":
                    increment = 10000;
                    break;
                case "XXX-KHz":
                    increment = 1000;
                    break;
                case "XXXX-KHz":
                    increment = 100;
                    break;
                case "XXXXX-KHz":
                    increment = 10;
                    break;
                case "XXXXXX-KHz":
                    increment = 1;
                    break;
            }
            
            var xxxxMHz = Number(document.getElementById("XXXX-MHz").innerText);
            var xxxMHz = Number(document.getElementById("XXX-MHz").innerText);
            var xxMHz = Number(document.getElementById("XX-MHz").innerText);
            var xMHz = Number(document.getElementById("X-MHz").innerText);
            var xKHz = Number(document.getElementById("X-KHz").innerText);
            var xxKHz = Number(document.getElementById("XX-KHz").innerText);
            var xxxKHz = Number(document.getElementById("XXX-KHz").innerText);
            var xxxxKHz = Number(document.getElementById("XXXX-KHz").innerText);
            var xxxxxKHz = Number(document.getElementById("XXXXX-KHz").innerText);
            var xxxxxxKHz = Number(document.getElementById("XXXXXX-KHz").innerText);
            
            var oldFrequency = (
                    (xxxxMHz *  1000000000) +
                    (xxxMHz *   100000000) +
                    (xxMHz *    10000000) +
                    (xMHz *     1000000) +
                    (xKHz *     100000) +
                    (xxKHz *    10000) +
                    (xxxKHz *   1000) +
                    (xxxxKHz *  100) +
                    (xxxxxKHz * 10) +
                     xxxxxxKHz);

            if ((oldFrequency >= 87500000) && (oldFrequency <= 107900000))
            {
                if (digitID == "X-KHz")
                {
                    if (xKHz % 2 == 1)
                    {
                        increment = 200000;  // special rule for FM broadcast - odd values only for 100x KHz
                    }
                }
            }

            var newFrequency = oldFrequency - increment;
            
            setFrequencyDigits(newFrequency);

            break;
        }
    }
    
    checkFrequencyRange();
    
    updateFrequencyInput();
}



function updateFrequencyInput()
{
    var xxxxMHz = Number(document.getElementById("XXXX-MHz").innerText);
    var xxxMHz = Number(document.getElementById("XXX-MHz").innerText);
    var xxMHz = Number(document.getElementById("XX-MHz").innerText);
    var xMHz = Number(document.getElementById("X-MHz").innerText);
    var xKHz = Number(document.getElementById("X-KHz").innerText);
    var xxKHz = Number(document.getElementById("XX-KHz").innerText);
    var xxxKHz = Number(document.getElementById("XXX-KHz").innerText);
    var xxxxKHz = Number(document.getElementById("XXXX-KHz").innerText);
    var xxxxxKHz = Number(document.getElementById("XXXXX-KHz").innerText);
    var xxxxxxKHz = Number(document.getElementById("XXXXXX-KHz").innerText);
    
    var newFrequency = (
            (xxxxMHz *  1000000000) +
            (xxxMHz *   100000000) +
            (xxMHz *    10000000) +
            (xMHz *     1000000) +
            (xKHz *     100000) +
            (xxKHz *    10000) +
            (xxxKHz *   1000) +
            (xxxxKHz *  100) +
            (xxxxxKHz * 10) +
             xxxxxxKHz);
    
    document.getElementById("frequency").value = newFrequency;
}


function checkFrequencyRange()
{
    var tunerDigitsDiv = document.getElementById("tuner-digits")
    
    var tunerDigitsArray = document.getElementsByClassName("tuner-digit");
    
    var frequency =
            tunerDigitsArray[0].innerText +
            tunerDigitsArray[1].innerText +
            tunerDigitsArray[2].innerText +
            tunerDigitsArray[3].innerText +
            tunerDigitsArray[4].innerText +
            tunerDigitsArray[5].innerText +
            tunerDigitsArray[6].innerText +
            tunerDigitsArray[7].innerText +
            tunerDigitsArray[8].innerText +
            tunerDigitsArray[9].innerText;
    
    frequency = Number(frequency);
    
    if (frequency < frequency_min)
    {
        setFrequencyDigits(frequency_min);
    }
    else if (frequency > frequency_max)
    {
        setFrequencyDigits(frequency_max);
    }
}


function setFrequencyDigits(frequency)
{
  //console.log("setFrequencyDigits - frequency "+frequency);
  newFrequency = "00000000000" + frequency;
  frequencyLength = newFrequency.length;
  newFrequency = newFrequency.substring(frequencyLength - 10);
  //console.log("setFrequencyDigits - frequency trimmed "+newFrequency);
  
  var tunerDigitsDiv = document.getElementById("tuner-digits")
  var tunerDigitsArray = document.getElementsByClassName("tuner-digit");
  var i;
  for (i = 0; i < 10; i++) {
    tunerDigitsArray[i].innerText = newFrequency[i];
  }

  /*
  var utterance  = new SpeechSynthesisUtterance();
  var newFrequencyFloat = newFrequency / 1000000;
  //utterance.rate = 1.5;
  utterance.text = newFrequencyFloat;
  speechSynthesis.speak(utterance);
  */
}



function listenButtonClicked(form)
{
  //console.log("listenButtonClicked");
  
  var formArray = $(form).serializeArray();
  var jsonData = JSON.stringify(formArray);

  // request to HTTP server to set radio tuning
  var getUrl = window.location;
  var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
  var listenButtonClickedUrl = baseUrl + "listenbuttonclicked.html";

  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
      if (this.readyState == 4 && this.status == 200) {
        // response received ok
        window.top.nowPlayingTitle = window.document.getElementById("listen_title");
      }
    };
  xhttp.open("POST", listenButtonClickedUrl, true);
  xhttp.send(jsonData);

  // handle the audio tag with the new source
  window.top.postMessage("startaudio", "*");

  //console.log("postMessage startaudio");
}




function frequencyListenButtonClicked()
{
  //console.log("frequencyListenButtonClicked");

    var tunerDigitsDiv = document.getElementById("tuner-digits")
    
    var tunerDigitsArray = document.getElementsByClassName("tuner-digit");
    
    var frequency =
            tunerDigitsArray[0].innerText +
            tunerDigitsArray[1].innerText +
            tunerDigitsArray[2].innerText +
            tunerDigitsArray[3].innerText +
            tunerDigitsArray[4].innerText +
            tunerDigitsArray[5].innerText +
            tunerDigitsArray[6].innerText +
            tunerDigitsArray[7].innerText +
            tunerDigitsArray[8].innerText +
            tunerDigitsArray[9].innerText;

    var sampleRateSelect = document.getElementById("sample_rate");
    var sampleRateOptions = sampleRateSelect.children;
    var sampleRateIndex = sampleRateSelect.selectedIndex;
    var sampleRateSelectedOption = sampleRateOptions[sampleRateIndex];
    var sample_rate = sampleRateSelectedOption.value;

    var tunerGainSelect = document.getElementById("tuner_gain");
    var tunerGainOptions = tunerGainSelect.children;
    var tunerGainIndex = tunerGainSelect.selectedIndex;
    var tunerGainSelectedOption = tunerGainOptions[tunerGainIndex];
    var tuner_gain = tunerGainSelectedOption.value;

    var stereo_flag = false;
    var stereoFlagSelect = document.getElementById("stereo_flag");
    if (stereoFlagSelect !== null)
    {
        var stereoFlagOptions = stereoFlagSelect.children;
        var stereoFlagIndex = stereoFlagSelect.selectedIndex;
        var tunerGainSelectedOption = stereoFlagOptions[stereoFlagIndex];
        stereo_flag = tunerGainSelectedOption.value;
    }

    var tuningArray = {frequency:frequency, sample_rate: sample_rate, tuner_gain: tuner_gain, stereo_flag: stereo_flag};

    var jsonData = JSON.stringify(tuningArray);

    // request to HTTP server to set radio tuning
    var getUrl = window.location;
    var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
    var frequencyListenButtonClickedUrl = baseUrl + "frequencylistenbuttonclicked.html";

    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
      //console.log("readyState="+this.readyState+", status="+this.status);
      if (this.readyState == 4 && this.status == 200) {
        // response received ok
        window.top.nowPlayingTitle = window.document.getElementById("listen_title");
      }
    };
    xhttp.open("POST", frequencyListenButtonClickedUrl, true);
    xhttp.send(jsonData);

    // handle the audio tag with the new source
    window.top.postMessage("startaudio", "*");

    //console.log("postMessage startaudio");
}






function scannerListenButtonClicked(form)
{
  //console.log("listenButtonClicked");
  
  var formArray = $(form).serializeArray();
  var jsonData = JSON.stringify(formArray);

  // request to HTTP server to set radio tuning
  var getUrl = window.location;
  var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
  var scannerListenButtonClickedUrl = baseUrl + "scannerlistenbuttonclicked.html";

  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
      if (this.readyState == 4 && this.status == 200) {
        // response received ok
        window.top.nowPlayingTitle = window.document.getElementById("listen_title");
      }
    };
  xhttp.open("POST", scannerListenButtonClickedUrl, true);
  xhttp.send(jsonData);

  // handle the audio tag with the new source
  window.top.postMessage("startaudio", "*");

  //console.log("postMessage startaudio");
}



function deviceListenButtonClicked(form)
{
  //console.log("deviceListenButtonClicked");
  
  var formArray = $(form).serializeArray();
  var jsonData = JSON.stringify(formArray);

  // request to HTTP server to set audio input device
  var getUrl = window.location;
  var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
  var listenButtonClickedUrl = baseUrl + "devicelistenbuttonclicked.html";

  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
      if (this.readyState == 4 && this.status == 200) {
        // response received ok
        window.top.nowPlayingTitle = window.document.getElementById("listen_title");
      }
    };
  xhttp.open("POST", listenButtonClickedUrl, true);
  xhttp.send(jsonData);

  // handle the audio tag with the new source
  window.top.postMessage("startaudio", "*");

  //console.log("postMessage startaudio");
}


function customTaskListenButtonClicked(form)
{
  //console.log("deviceListenButtonClicked");
  
  var formArray = $(form).serializeArray();
  var jsonData = JSON.stringify(formArray);

  // request to HTTP server to set audio input device
  var getUrl = window.location;
  var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
  var listenButtonClickedUrl = baseUrl + "customtasklistenbuttonclicked.html";

  var xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
      if (this.readyState == 4 && this.status == 200) {
        // response received ok
        window.top.nowPlayingTitle = window.document.getElementById("listen_title");
      }
    };
  xhttp.open("POST", listenButtonClickedUrl, true);
  xhttp.send(jsonData);

  // handle the audio tag with the new source
  window.top.postMessage("startaudio", "*");

  //console.log("postMessage startaudio");
}


//var displayUpdateInterval = 5000;  // five seconds
var displayUpdateInterval = 0;  // fast updates
var currentInterval = 0;
var pollingInterval = 250;  // four times per second

function periodicUpdate()
{
  //console.log("periodicUpdate");
  
    if (currentInterval >= displayUpdateInterval)
    {
      // request to HTTP server to get radio status
      var getUrl = window.location;
      var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
      var nowPlayingStatusUrl = baseUrl + "nowplayingstatus.html";

      var xhttp = new XMLHttpRequest();
      xhttp.onreadystatechange = function() {
        if (this.readyState == 4 && this.status == 200) {
          // response received ok
          updateStatusDisplay(xhttp.response);
        }
      };
      xhttp.open("POST", nowPlayingStatusUrl, true);
      xhttp.send();
    }
    
    currentInterval = currentInterval + pollingInterval;
    
    if (currentInterval >= displayUpdateInterval)
    {
        currentInterval = 0;
    }
}

// Printing description of statusData:
// {"modulation":"fm","oversampling":4,"signal_level":19,"options":"","frequency_scan_interval":0,"tuner_gain":49.7,"station_name":"KUAR-NPR Little Rock 89.1","atan_math":"std","sampling_mode":0,"sample_rate":85000,"frequency_mode":0,"squelch_level":0,"id":4,"tuner_agc":1,"frequency_scan_end":0,"fir_size":9,"audio_output_filter":"vol 1","frequency":89100000}
function updateStatusDisplay(statusData)
{
    var statusObj = JSON.parse(statusData);
    
    var rtlsdr_task_mode = statusObj.rtlsdr_task_mode;
    
    var audio_output_filter = statusObj.audio_output_filter;
    var atan_math = statusObj.atan_math;
    var fir_size = statusObj.fir_size;
    var frequency = statusObj.frequency;
    var frequency_mode = statusObj.frequency_mode;
    var frequency_scan_end = statusObj.frequency_scan_end;
    var frequency_scan_interval = statusObj.frequency_scan_interval;
    var modulation = statusObj.modulation;
    var options = statusObj.options;
    var oversampling = statusObj.oversampling;
    var sample_rate = statusObj.sample_rate;
    var sampling_mode = statusObj.sampling_mode;
    var short_frequency = statusObj.short_frequency;
    var signal_level = statusObj.signal_level;
    var squelch_level = statusObj.squelch_level;
    var station_name = statusObj.station_name;
    var tuner_agc = statusObj.tuner_agc;
    var tuner_gain = statusObj.tuner_gain;
    
    if (rtlsdr_task_mode == "frequency")
    {
        var nowPlayingName = document.getElementById("now-playing-name");
        if (nowPlayingName != null)
        {
            nowPlayingName.innerHTML = station_name;
        }
    }

    if (rtlsdr_task_mode == "scan")
    {
        audio_output_filter = statusObj.scan_audio_output_filter;
        atan_math = statusObj.scan_atan_math;
        fir_size = statusObj.scan_fir_size;
        frequency_mode = statusObj.scan_frequency_mode;
        modulation = statusObj.scan_modulation;
        options = statusObj.scan_options;
        oversampling = statusObj.scan_oversampling;
        sample_rate = statusObj.scan_sample_rate;
        sampling_mode = statusObj.scan_sampling_mode;
        squelch_level = statusObj.scan_squelch_level;
        tuner_agc = statusObj.scan_tuner_agc;
        tuner_gain = statusObj.scan_tuner_gain;
    }
    
    var nowPlayingDetails = document.getElementById("now-playing-details");
    if (nowPlayingDetails != null)
    {
        var statusHtml = "<div style=\"position: relative;\">";
        statusHtml += "<br><br>";

        
        if (rtlsdr_task_mode == "scan")
        {
          statusHtml += "<span id='now-playing-details' style='overflow-x: scroll; white-space: nowrap;'>";

          statusHtml += "name: ";
          statusHtml += station_name;
          statusHtml += "<br>";
          
          statusHtml += "</span>"
        }
        
        statusHtml += "frequency: ";
        statusHtml += short_frequency;
        statusHtml += "<br>";
        statusHtml += "signal level: ";
        statusHtml += signal_level;
        statusHtml += "<br>";

        if (rtlsdr_task_mode == "scan")
        {
          statusHtml += "<br><br>CATEGORY SCANNER SETTINGS: <br>";
        }
        
        statusHtml += "squelch level: ";
        statusHtml += squelch_level;
        statusHtml += "<br>";
        statusHtml += "modulation: ";
        statusHtml += modulation;
        statusHtml += "<br>";
        statusHtml += "sample rate: ";
        statusHtml += sample_rate;
        statusHtml += "<br>";
        statusHtml += "sampling mode: ";
        statusHtml += sampling_mode;
        statusHtml += "<br>";
        statusHtml += "oversampling: ";
        statusHtml += oversampling;
        statusHtml += "<br>";
        statusHtml += "tuner gain: ";
        statusHtml += tuner_gain;
        statusHtml += "<br>";
        statusHtml += "tuner agc: ";
        statusHtml += tuner_agc;
        statusHtml += "<br>";
        statusHtml += "rtl-sdr options: pad ";
        statusHtml += options;
        statusHtml += "<br>";
        statusHtml += "fir size: ";
        statusHtml += fir_size;
        statusHtml += "<br>";
        statusHtml += "atan math: ";
        statusHtml += atan_math;
        statusHtml += "<br>";
        statusHtml += "audio output filter: rate 48000 ";
        statusHtml += audio_output_filter;
        statusHtml += "<br>";
        statusHtml += "<div>";

        nowPlayingDetails.innerHTML = statusHtml;
    }
    
    window.top.nowPlayingTitle = station_name;

    var nowPlayingNavBarLink = window.top.document.getElementById("nowPlayingNavBarLink");
    nowPlayingNavBarLink.innerText = "NOW PLAYING: " + station_name;
}

var intervalID = setInterval(function(){periodicUpdate();}, 20000);     // for Now Playing periodic updates using setInterval()

function startNowPlayingUpdates()
{
    clearInterval(intervalID);

    intervalID = setInterval(function(){periodicUpdate();}, pollingInterval);   // fast updates
}


function stopNowPlayingUpdates()
{
    clearInterval(intervalID);

    intervalID = setInterval(function(){periodicUpdate();}, 20000);    // update every 20 seconds
}


function applyMP3Settings(form)
{
  //console.log("frequencyListenButtonClicked");

    var bitrateSelect = document.getElementById("bitrate_select");
    var bitrateOptions = bitrateSelect.children;
    var bitrateIndex = bitrateSelect.selectedIndex;
    var bitrateSelectedOption = bitrateOptions[bitrateIndex];
    var bitrate = bitrateSelectedOption.value;

    var encodingQualitySelect = document.getElementById("encoding_quality_select");
    var encodingQualityOptions = encodingQualitySelect.children;
    var encodingQualityIndex = encodingQualitySelect.selectedIndex;
    var encodingQualitySelectedOption = encodingQualityOptions[encodingQualityIndex];
    var encoding_quality = encodingQualitySelectedOption.value;

    var mp3SettingsArray = {bitrate: bitrate, encoding_quality: encoding_quality};

    var jsonData = JSON.stringify(mp3SettingsArray);

    // request to HTTP server to set radio tuning
    var getUrl = window.location;
    var baseUrl = getUrl .protocol + "//" + getUrl.host + "/";
    var applyMP3SettingsButtonClickedUrl = baseUrl + "applymp3settings.html";

    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
      //console.log("readyState="+this.readyState+", status="+this.status);
      if (this.readyState == 4 && this.status == 200) {
        // response received ok
        alert("The MP3 streaming settings were changed, and the servers are restarting.  Press the ► Play button to start audio.")
      }
    };
    xhttp.open("POST", applyMP3SettingsButtonClickedUrl, true);
    xhttp.send(jsonData);

    // handle the audio tag with the new source
    //window.top.postMessage("startaudio", "*");

    //console.log("postMessage startaudio");
}

