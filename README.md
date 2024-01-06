# Nimble Commander
Nimble Commander is a dual-pane file manager for macOS, which was developed with an emphasis on performance, keyboard navigation and flexibility. Project's website: https://magnumbytes.com.  
This repository contains the project's source code.

# How to Build
**Prerequisites**  
Xcode15, preferrebly Xcode15.1.0.  

Make sure that the correct Xcode version is selected:
```
xcode-select -p
```
If it's not - adjust this setting:
```
sudo xcode-select -s /Application/ProperXcodeVersionPath/
```

**Getting the source code**  
Clone the repository in appropriate directory:
```
git clone https://github.com/mikekazakov/nimble-commander
```

**Building an unsigned version**  
Use the following script to check if the build system works as expected:
```
cd nimble-commander/Scripts
./build_unsigned_and_run.sh
```
If execution was successful, this script will run the freshly built version of Nimble Commander.  
Location of resulting application bundle depends on current Xcode settings, by default it can be found here:  
~/Library/Developer/Xcode/DerivedData/NimbleCommander-.../Build/Products/Debug_Unsigned/NimbleCommander-Unsigned.app

# Exploring the source code
Just open `Source/NimbleCommander/NimbleCommander.xcodeproj` in Xcode and select the proper scheme: NimbleCommander-Unsigned.  
The source code is ready to be built and run.  
There re 10 sub-projects in the codebase, apart from the main one:
  * Base - low-level general-purpose facilities.
  * Config - configuration facilities.
  * CUI - common UI components.
  * Operations - a set of file operations running on top of the VFS layer.
  * Panel - components of the file panels.
  * RoutedIO - AdminMode-related code, including privileged helper and client-side interface.
  * Term - built-in terminal emulator.
  * Utility - platform-dependent utilities.
  * VFS - virtual file systems: generic interface and various implementations.
  * VFSIcon - production of icons and thumbnails for VFS entries.
  * Viewer - built-in viewer.

# Limitations
This source code is the same as the one used to build the officially distributed versions of Nimble Commander.
However, the public repository does not contain any sensitive information like accounts, addresses, keys, and alike.
Thus a few parts, which specifically rely on that information, might not work as expected.

# License
Copyright (C) 2013-2024 Michael Kazakov (mike.kazakov@gmail.com)  
The source code is distributed under GNU General Public License version 3.
