# G1 iOS Sample Project



<p float="left">
  <img src="https://github.com/callbacked/g1-sample/blob/main/screenshots/IMG_0979.PNG?raw=true" width="200" />
  <img src="https://github.com/callbacked/g1-sample/blob/main/screenshots/IMG_0983.PNG?raw=true" width="200" /> 
  <img src="https://github.com/callbacked/g1-sample/blob/main/screenshots/IMG_0984.PNG?raw=true" width="200" />
  <img src="https://github.com/callbacked/g1-sample/blob/main/screenshots/IMG_0985.PNG?raw=true" width="200" />
</p>
This project is a fork based off of the G1Sample Project by @FilipposPirpilidis for the Even Realities G1 Glasses

  

BIG GIANT DISCLAIMER: I am not an iOS dev, this is my first time working with Swift because I wanted to use the speech recognition api, so fair warning to anyone who wants to see and modify the awful code I wrote with some assistance from AI.

This project was more to see how much of the glasses functionality can be implemented without an SDK.

  

---

  

## Features

  

-  **Bluetooth Communication**: Seamlessly connects the G1 glasses to an iPhone using Bluetooth.

-  **Voice-to-Text Processing**: Retrieves voice data from the G1 glasses and converts it into text to query an AI model from your own supplied OpenAI Compatible API

-  **Battery Monitoring**: Monitors the battery level of the G1 glasses and displays it on screen (in full mode).

-  **App Controls**: Allows the user to control the glasses from the app to change the dashboard mode, adjust dashboard positioning, and adjust the brightness level.

-  **Quick Notes**: Allows the user to add quick notes to the glasses from the app.

-  **Wake Word Detection**: Turns on the microphone every 30 seconds to listen to a user's wake word to activate the AI.

-- to use it, you enable it in the app settings and then tilt your head up to engage the dashboard and say "Hey Jarvis"

  
  

---

  

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

https://github.com/emingenc/even_glasses 
https://github.com/emingenc/g1_flutter_blue_plus/tree/main 
https://github.com/NyasakiAT/G1-Navigate 
https://github.com/meyskens/fahrplan

