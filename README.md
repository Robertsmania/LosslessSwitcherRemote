# LosslessSwitcherRemote
iOS companion app for LosslessSwitcher
<p align="center">
  <img width="550" alt="header image with app icon" src="https://user-images.githubusercontent.com/23420208/164895903-1c95fe89-6198-433a-9100-8d9af32ca24f.png">

</p>

#  
This is an iOS companion app for the Network Server version of the LosslessSwitcher macOS app:
https://github.com/Robertsmania/LosslessSwitcherNetworkServer

That project is a fork of the LosslessSwitcher project:
https://github.com/vincentneo/LosslessSwitcher

## Installation
You can clone or download the source code from a release,  then build and run it on your iOS device from Xcode.

Or, you can get the LosslessSwitcherRemote iOS app from TestFlight.

Use this URL to join the beta test and download the app:

https://testflight.apple.com/join/QDtXe7tV

I will do my best to keep the TestFlight version in sync with whats here on GitHub.

## App details

Here is a video of the LosslessSwitcher Remote iOS app in use:

[![Watch the video](https://img.youtube.com/vi/wjMEUtEg41s/0.jpg)](https://youtu.be/wjMEUtEg41s)

If you start the iOS app with no servers running this is the screen you get.  You can manually refresh and look for servers, but if none are running on your network this is as far as it goes:

![LLS_Remote_iOS_01](https://user-images.githubusercontent.com/11642124/231374790-244ad537-3f7a-4162-b49b-a50f89f9fcf8.png)

When you run the network enabled version of LosslessSwitcher, it appears on the network and the iOS app will detect it.  If it is the only service discovered, the iOS app will connect to it automatically. This screen shows the Manage Connection Details screen where you can see all the discovered services and pick the one you want to connect to:

![LLS_Remote_iOS_Connection_03](https://user-images.githubusercontent.com/11642124/231379797-41d052b9-9809-4385-bc72-2cab677830b0.png)

**This is the main UI when the app is in use:** 

![LLS_iOS_Remote_Main](https://user-images.githubusercontent.com/11642124/231378233-5f01ad1e-b5bb-44f0-85bb-9c73eefb0d96.png)

- At the top it shows the currently connected host name and the output device.  
- You can click the Show Connection Details button to get the screen above which shows all the discovered services and lets you connect to a different service.  
- The Refresh button updates all the data from the server, but is not normally needed as all the operations will update the UI with data that comes back from the server after any operation has been executed.
- The current and detected frequency rates are shown along with the current status of the auto-switching option.
- The buttons below that do pretty much what they say:
- Toggle Auto Switch turns on or off the auto switch feature.  When it is off, LosslessSwitcher will show the detected frequency rate, but the current setting will not change unless you use one of the manual options.
- Set Rate to Detected - mostly useful if auto switching is disabled.
- The picker shown has the supported frequency rates for the current output device.  You can select one and use the Set Rate to Selected button to apply it.

It supports multiple devices and multiple servers.  Each iOS device can select which server it wants to control and the servers do a best effort to send updates to all clients that are connected to them.
