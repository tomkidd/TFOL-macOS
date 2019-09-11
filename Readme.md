# Thirty Flights of Loving for macOS

This repo contains the source code for the game *Thirty Flights of Loving* for the Mac by [Blendo Games](http://blendogames.com/). The predecessor game *Gravity Bone* is also playable via a menu option.

*Thirty Flights of Loving* is available as a retail purchase from [Steam](https://store.steampowered.com/app/214700/Thirty_Flights_of_Loving/), [itch.io](https://blendogames.itch.io/thirtyflightsofloving) and [Blendo by way of Humble Bundle](http://blendogames.com/thirtyflightsofloving/buy.htm). 

Although *Gravity Bone* was released as a free game, there was never an official standalone port of it to the Mac and so as of this writing this version of the code needs the files from *Thirty Flights of Loving*, which also includes the other game. 

The Blendo website contained a [link](http://blendogames.com/thirtyflightsofloving/faq.htm) to the source code for the Windows version but not the Mac version. After writing to Brendon Chung he supplied me with the Mac version of the source code. Both games are based off of the GPL-licensed source code for *Quake II* (aka "id Tech 2") and so Blendo has no issue with releasing it here.

The DRM-free build of the original port of *Thirty Flights of Loving* for the Mac was a 32-bit app and was poised to go extinct upon the release of macOS 10.15 Catalina, though it looks like the Steam version has seen some of the necessary updates. This repository contains the work I did to get the game running on a current Mac development environment. 

*Thirty Flights of Loving* and its predecessor *Gravity Bone* were done using the KMQuake2 source port, and the Mac version was done using a port of KMQuake2 to the Mac by way of the fruitz-of-dojo port. This repository contains additional code from MaddTheSane and the YQuake2 project in order to fix some bugs introduced with 64-bit mode.

At the time of this writing I have commented out Steam functionality. It links to libraries included in the code, this may or may not be the right way to do it but I was looking to make as few changes as possible. 

Have fun. For any questions I can be reached at [tomkidd@gmail.com](mailto:tomkidd@gmail.com)
