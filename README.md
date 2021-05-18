# 835FinalShowcase

There are 2 parts to working this system: The iPhone/Mac, and the Simulated EIT Band

## iPhone and Mac Setup
A basic implementation can be achieved by opening any of the project folders as Xcode projects and compiling them to build on an iPhone. The app may prompt you to accept a user certificate, you can do so by going to Settings > General > Profiles & Device Management, and choosing to trust the proper Apple Development account (defaults to joverdejo@gmail.com) 


## Simulated EIT Band
Becuase there are no EIT bands currently available, I wrote a script that simulates sending commands from the EIT band to the iPhone. To run the script, just run EITViz_ESP32.ino on an ESP32. Before hitting "connect" on the app, make sure you hit the boot button on the ESP, or just reset the system, so that the calibration works properly.

After both of these steps are completed, you should be able to run the apps by simply hitting "connect" on any of the projects!
