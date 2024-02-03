[![Build and Test](https://github.com/mikekazakov/nimble-commander/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/mikekazakov/nimble-commander/actions/workflows/build.yml)
[![Nightly Build](https://github.com/mikekazakov/nimble-commander/actions/workflows/nightly.yml/badge.svg?branch=main)](https://github.com/mikekazakov/nimble-commander/actions/workflows/nightly.yml)

# Nimble Commander
Nimble Commander is a free dual-pane file manager for macOS, designed with a focus on speed, keyboard-based navigation, and flexibility.  
The project's aim is to blend the user experience of classic file managers from the '80s-'90s with the modern look and feel of Mac computers.  
Visit the project's website at: https://magnumbytes.com.  

# Getting Nimble Commander

## Nightly Builds
You can download the latest nightly build of the app from [GitHub Actions](https://github.com/mikekazakov/nimble-commander/actions/workflows/nightly.yml).  
Go to the most recent integration and select the `nimble-commander-nightly` in the `Artifacts` section (a GitHub account is required).

## Current Release
Direct download link: https://magnumbytes.com/downloads/releases/nimble-commander.dmg.  
Available on Mac App Store: https://itunes.apple.com/app/files-lite/id905202937?ls=1&mt=12.  
Install via Homebrew: `brew install nimble-commander`.  

## Past Releases
Access all previous releases at https://github.com/mikekazakov/nimble-commander-releases. 

# Building from Source
**Prerequisites**  
Recommended: Xcode15, ideally Xcode15.1.0.  
Ensure you have the correct Xcode version: `xcode-select -p`.  
If not, change it using: `sudo xcode-select -s /Application/ProperXcodeVersionPath/`.  

**Obtaining the Source Code**  
To clone the repository, use: `git clone https://github.com/mikekazakov/nimble-commander`.  

**Building an Unsigned Version**  
To verify the build system's functionality, use this script: `cd nimble-commander/Scripts && ./build_unsigned_and_run.sh`.  
Upon successful execution, this script will launch the newly compiled version of Nimble Commander.  
The location of the resulting application bundle varies based on Xcode settings, but is typically found here:  
`~/Library/Developer/Xcode/DerivedData/NimbleCommander-.../Build/Products/Debug_Unsigned/NimbleCommander-Unsigned.app`.

# Exploring the Source Code
Simply open `Source/NimbleCommander/NimbleCommander.xcodeproj` in Xcode and select the right scheme: NimbleCommander-Unsigned.  
The source code is ready for building and execution.  

The codebase includes 10 sub-projects, in addition to the primary one:
  * Base - foundational, general-purpose tools.
  * Config - configuration tools.
  * CUI - shared UI components.
  * Operations - file operation suite running atop the VFS layer.
  * Panel - components of the file panels.
  * RoutedIO - Admin Mode code, including the privileged helper and client interface.
  * Term - integrated terminal emulator.
  * Utility - system-specific utilities.
  * VFS - virtual file systems: generic interface and various implementations.
  * VFSIcon - production of icons and thumbnails for VFS entries.
  * Viewer - integrated file viewer.

# Limitations
This source code is identical to that used for the official Nimble Commander builds.  
However, the public repository excludes sensitive data such as accounts, addresses, and keys.  
Therefore, some components dependent on this information may not function as intended.

# License
Copyright (C) 2013-2024 Michael Kazakov (mike.kazakov@gmail.com)  
The source code is distributed under GNU General Public License version 3.
