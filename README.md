# G1 iOS Sample Project



<p float="left">
  <img src="https://github.com/callbacked/g1-sample/blob/main/screenshots/IMG_95220C2ACE28-1.jpeg?raw=true" width="200" />
  <img src="https://github.com/callbacked/g1-sample/blob/main/screenshots/IMG_0983.PNG?raw=true" width="200" /> 
  <img src="https://github.com/callbacked/g1-sample/blob/main/screenshots/IMG_0984.PNG?raw=true" width="200" />
  <img src="https://github.com/callbacked/g1-sample/blob/main/screenshots/IMG_0985.PNG?raw=true" width="200" />
</p>

This project is a fork based off of the G1Sample Project by @FilipposPirpilidis for the Even Realities G1 Glasses.


**BIG GIANT DISCLAIMER:** I am not an iOS dev, this is my first time working with Swift because I wanted to use the speech recognition api, so fair warning to anyone who wants to see and modify the awful code I wrote with some assistance from AI. 

This project was more to see how much of the glasses functionality can be implemented without an SDK. Not a polished app by any means. This is a proof of concept if anything -- expect bugs.

  

---

  

## Features

  

-  **Bluetooth Communication**: Seamlessly connects the G1 glasses to an iPhone using Bluetooth.

-  **Voice-to-Text Processing**: Retrieves voice data from the G1 glasses and converts it into text to query an AI model from your own supplied OpenAI Compatible API

-  **Battery Monitoring**: Monitors the battery level of the G1 glasses and displays it on screen (in full mode).

-  **Weather API Integration**: Retrieves weather data from Open-Meteo's free API based on the users current location.

-  **App Controls**: Allows the user to control the glasses from the app to change the dashboard mode, adjust dashboard positioning, head up tilt angle adjustment, brightness level adjustment (with auto as an option).
	- note: distance adjustment does not work 

-  **Quick Notes**: Allows the user to add quick notes to the glasses from the app.

-  **Wake Word Detection**: Turns on the microphone every 30 seconds to listen to a user's wake word to activate the AI.

	-- to use it, you enable it in the app settings and then tilt your head up to engage the dashboard and say "Hey Jarvis". It is very inconsistent to get the microphone to engage so it may take a couple tries. In theory if improved upon, it could open up to be used for voice based controls.

- **Translation**: Allows the user to translate text from one language to another using an open endpoint in Google's Translate API. This endpoint can close at any time so it should not be relied on. 
Ideally, for production use we would use an actual API for translation. 
  
  

---

## What Doesn't Work

-  **Distance Adjustment**: The distance adjustment feature does not work as I can't figure out the correct command to send to the G1 glasses to adjust the distance.

- **Touchpad Gestures**: The touchpad gestures like holding down the left side to engage the default Even AI app and holding down the right side to engage quick notes does not do anything, it still has the same default behavior

- **Changing Widgets**: As of right now, only the quick note widget is available to use.


## Requirements

  

-  **iOS 13.0** or later

- Xcode 14 or later

- G1 glasses from Even Realities (Works on firmware 1.5 as of writing this)

  

---

  

## Technologies Used

  

-  **Swift**: Core programming language

-  **UIKit**: User Interface framework

-  **Combine**: Framework for handling asynchronous events

-  **CoreBluetooth**: Framework for managing Bluetooth connectivity

  

---

  

## Setup Instructions

1. Clone Repo

2. Open the G1Sample.xcodeproj file in Xcode

3. Hit the play button to build and run

## Thanks
A lot of the glasses functionality was mapped out by those reverse engineering the g1 glasses. I would like to thank them for their work, as I would not have come close to finishing this without
their insights. Additionally, I would like to thank those who put these insights into practice by building libraries and apps out of them for us to draw inspiration from.

 - https://github.com/emingenc/even_glasses
 - https://github.com/emingenc/g1_flutter_blue_plus/
 - https://github.com/NyasakiAT/G1-Navigate
 - https://github.com/meyskens/fahrplan