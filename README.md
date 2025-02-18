# G1 iOS Sample Project

This project is a fork based off of the G1Sample Project by @FilipposPirpilidis for the Even Realities G1 Glasses

BIG GIANT DISCLAIMER: I am not an iOS dev, this is my first time working with Swift because I wanted to use the speech recognition api, so fair warning to anyone who wants to see and modify the awful code I wrote with some assistance from AI.

---

## Features

- **Bluetooth Communication**: Seamlessly connects the G1 glasses to an iPhone using Bluetooth.
- **Voice-to-Text Processing**: Retrieves voice data from the G1 glasses and converts it into text to query an AI model from your own supplied OpenAI Compatible API
- **Battery Monitoring**: Monitors the battery level of the G1 glasses and displays it on screen (in full mode).
- **App Controls**: Allows the user to control the glasses from the app to change the dashboard mode, adjust dashboard positioning, and adjust the brightness level.
- **Quick Notes**: Allows the user to add quick notes to the glasses from the app.
- **Wake Word Detection**: Turns on the microphone every 30 seconds to listen to a user's wake word to activate the AI.
-- to use it, you enable it in the app settings and then tilt your head up to engage the dashboard and say "Hey Jarvis"


---

## Requirements

- **iOS 13.0** or later
- Xcode 14 or later
- G1 glasses from Even Realities (Works on firmware 1.5 as of writing this)

---

## Technologies Used

- **Swift**: Core programming language
- **UIKit**: User Interface framework
- **Combine**: Framework for handling asynchronous events
- **CoreBluetooth**: Framework for managing Bluetooth connectivity

---

## Setup Instructions
1. Clone Repo
2. Open the G1Sample.xcodeproj file in Xcode
3. Hit the play button to build and run
