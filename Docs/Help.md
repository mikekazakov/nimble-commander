# Nimble Commander Help

## Getting Started

### Introduction

Nimble Commander is a free dual-pane file manager for macOS, designed with a focus on speed, keyboard-based navigation, and flexibility. The project aims to blend the user experience of classic file managers from the '80s and '90s with the modern look and feel of Mac computers.

### System Requirements

Nimble Commander supports any Mac running the following versions of macOS:

- macOS 10.15 Catalina
- macOS 11 Big Sur
- macOS 12 Monterey
- macOS 13 Ventura
- macOS 14 Sonoma

It runs natively on both Intel and Arm architectures.

### Running the Application

Simply double-click on the Nimble Commander icon to start it.

### Access Permissions

If you downloaded Nimble Commander from the Mac App Store, the application will request permissions when navigating to a new location. This requirement is imposed on all applications published in the Mac App Store as a safety measure to prevent unauthorized access outside of the sandbox container. You can revoke granted access permissions at any time by clicking `Settings > General > Granted filesystem access > Reset`. The permission request will appear as shown below:

![NC asking for an access permission](Help-sandbox-perm.png)

Even if you downloaded Nimble Commander outside of the Mac App Store, accessing certain locations will require granting permissions. As of this writing, the list of such locations includes:

- Desktop Folder
- Documents Folder
- Downloads Folder
- Network Volumes
- iCloud Drive

To use Nimble Commander in these locations, you need to grant the necessary permissions in System Settings under `Privacy & Security > Files and Folders` section. Alternatively, you can grant Nimble Commander Full Disk Access in System Settings under `Privacy & Security > Full Disk Access` section.

### Version Differences

There are two existing versions of Nimble Commander: the sandboxed version available in the Mac App Store, and the standalone version available for direct download from the website. Both versions are mostly equal in terms of functionality. The sandboxed version consumes slightly more resources due to sandboxing, but it provides an additional layer of protection. The notable features missing from the sandboxed version are:

- Admin mode, as sandboxed applications are not allowed to install privileged helper tools.
- Integrated terminal, as sandboxed applications are not allowed to send termination signals to other applications.
- Mounting network shares, as sandboxed applications are not allowed to use the NetFS framework.
- Interceping F1..F19 keystrokes as functional without holding the Fn modifier, as sandboxed applications cannot ask for accessbility permissions.

## File Panels

### Introduction
_to be written_

### Navigation
_to be written_

### Selection
_to be written_

### Quick Search
_to be written_

### Quick Lists
_to be written_

### Tabs
_to be written_

## Operations
_to be written_

## Virtual File Systems
_to be written_

## Integrated Viewer
_to be written_

## Integrated Terminal
_to be written_

## Customization
_to be written_

### Themes
_to be written_

### Hotkeys
_to be written_

Available hotkeys are listed below. These are the default values, which can be altered later. Some actions do not have a default hotkey, but they can still be accessed via the application’s menu.

| Action                                    | Key Equivalent            |
| ----------------------------------------- | ------------------------- |
| _**Nimble Commander Menu**_               |                           |
| &nbsp; About                              |                           |
| &nbsp; Preferences                        | Cmd + ,                   |
| &nbsp; Enable Admin Mode                  |                           |
| &nbsp; Hide Nimble Commander              | Cmd + H                   |
| &nbsp; Hide Others                        | Alt+Cmd+H                 |
| &nbsp; Show All                           |                           |
| &nbsp; Quit Nimble Commander              | Cmd + Q                   |
| &nbsp; Quit and Close All Windows         | Alt + Cmd + Q             |
| _**File Menu**_                           |                           |
| &nbsp; New Window                         | Cmd + N                   |
| &nbsp; New Folder                         | Shift + Cmd + N           |
| &nbsp; New Folder with Selection          | Ctrl + Cmd + N            |
| &nbsp; New File                           | Alt + Cmd + N             |
| &nbsp; New Tab                            | Cmd + T                   |
| &nbsp; Enter                              | Return                    |
| &nbsp; Open                               | Shift + Return            |
| &nbsp; Reveal in Opposite Panel           | Alt + Return              |
| &nbsp; Reveal in Opposite Panel Tab       | Alt + Cmd + Return        |
| &nbsp; Paste Filename to Terminal         | Ctrl + Alt + Return       |
| &nbsp; Paste Filenames to Terminal...     | Ctrl + Alt + Cmd + Return |
| &nbsp; Calculate Folders Sizes            | Shift + Alt + Return      |
| &nbsp; Calculate All Folders Sizes        | Ctrl + Shift + Return     |
| &nbsp; Calculate Checksum                 | Shift + Cmd + K           |
| &nbsp; Duplicate                          | Cmd + D                   |
| &nbsp; Add to Favorites                   | Cmd + B                   |
| &nbsp; Close                              | Cmd + W                   |
| &nbsp; Close Window                       | Shift + Cmd + W           |
| &nbsp; Close Other Tabs                   | Alt + Cmd + W             |
| &nbsp; Find...                            | Cmd + F                   |
| &nbsp; Find with Spotlight...             | Alt + Cmd + F             |
| &nbsp; Find Next                          | Cmd + G                   |
| _**Edit Menu**_                           |                           |
| &nbsp; Copy                               | Cmd + C                   |
| &nbsp; Paste                              | Cmd + V                   |
| &nbsp; Move Item Here                     | Alt + Cmd + V             |
| &nbsp; Select All                         | Cmd + A                   |
| &nbsp; Deselect All                       | Alt + Cmd + A             |
| &nbsp; Invert Selection                   | Ctrl + Cmd + A            |
| _**View Menu**_                           |                           |
| &nbsp; Toggle Single-Pane Mode            | Shift + Cmd + P           |
| &nbsp; Swap Panels                        | Cmd + U                   |
| &nbsp; Sync Panels                        | Alt + Cmd + U             |
| &nbsp; _**View Mode Submenu**_            |                           |
| &nbsp; &nbsp; Toggle Short View Mode      | Ctrl + 1                  |
| &nbsp; &nbsp; Toggle Medium View Mode     | Ctrl + 2                  |
| &nbsp; &nbsp; Toggle Full View Mode       | Ctrl + 3                  |
| &nbsp; &nbsp; Toggle Wide View Mode       | Ctrl + 4                  |
| &nbsp; &nbsp; Toggle View Mode V          | Ctrl + 5                  |
| &nbsp; &nbsp; Toggle View Mode VI         | Ctrl + 6                  |
| &nbsp; &nbsp; Toggle View Mode VII        | Ctrl + 7                  |
| &nbsp; &nbsp; Toggle View Mode VIII       | Ctrl + 8                  |
| &nbsp; &nbsp; Toggle View Mode IX         | Ctrl + 9                  |
| &nbsp; &nbsp; Toggle View Mode X          | Ctrl + 0                  |
| &nbsp; _**Sorting Submenu**_              |                           |
| &nbsp; &nbsp; Sort By Name                | Ctrl + Cmd + 1            |
| &nbsp; &nbsp; Sort By Extension           | Ctrl + Cmd + 2            |
| &nbsp; &nbsp; Sort By Modified Time       | Ctrl + Cmd + 3            |
| &nbsp; &nbsp; Sort By Size                | Ctrl + Cmd + 4            |
| &nbsp; &nbsp; Sort By Creation Time       | Ctrl + Cmd + 5            |
| &nbsp; &nbsp; Sort By Added Time          | Ctrl + Cmd + 6            |
| &nbsp; &nbsp; Sort By Accessed Time       | Ctrl + Cmd + 7            |
| &nbsp; &nbsp; Separate Folders From Files |                           |
| &nbsp; &nbsp; Extensionless Folders       |                           |
| &nbsp; &nbsp; Case-Sensitive Comparison   |                           |
| &nbsp; &nbsp; Numeric Comparison          |                           |
| &nbsp; Show Hidden Files                  | Shift + Cmd + .           |
| &nbsp; _**Panels Position Submenu**_      |                           |
| &nbsp; &nbsp; Move Left                   | Ctrl + Alt + Left         |
| &nbsp; &nbsp; Move Right                  | Ctrl + Alt + Right        |
| &nbsp; &nbsp; Move Up                     | Ctrl + Alt + Up           |
| &nbsp; &nbsp; Move Down                   | Ctrl + Alt + Down         |
| &nbsp; &nbsp; Show Panels                 | Ctrl + Alt + O            |
| &nbsp; &nbsp; Focus Overlapped Terminal   | Ctrl + Alt + Tab          |
| &nbsp; Show Tab Bar                       | Shift + Cmd + T           |
| &nbsp; Show Toolbar                       | Alt + Cmd + T             |
| &nbsp; Show Terminal                      | Alt + Cmd + O             |
| _**Go Menu**_                             |                           |
| &nbsp; Left Panel...                      | F1                        |
| &nbsp; Right Panel...                     | F2                        |
| &nbsp; Back                               | Cmd + [                   |
| &nbsp; Forward                            | Cmd + ]                   |
| &nbsp; Enclosing Folder                   | Cmd + Up                  |
| &nbsp; Enter                              | Cmd + Down                |
| &nbsp; Follow                             | Cmd + Right               |
| &nbsp; Documents                          | Shift + Cmd + O           |
| &nbsp; Desktop                            | Shift + Cmd + D           |
| &nbsp; Downloads                          | Alt + Cmd + L             |
| &nbsp; Home                               | Shift + Cmd + H           |
| &nbsp; Library                            |                           |
| &nbsp; Applications                       | Shift + Cmd + A           |
| &nbsp; Utilities                          | Shift + Cmd + U           |
| &nbsp; Root                               |                           |
| &nbsp; Processes List                     | Alt + Cmd + P             |
| &nbsp; _**Favorites Submenu**_            |                           |
| &nbsp; &nbsp; Manage Favorites...         | Ctrl + Cmd + B            |
| &nbsp; _**Recently Closed Submenu**_      |                           |
| &nbsp; &nbsp; Restore Last Closed Panel   | Shift + Cmd + R           |
| &nbsp; _**Quick Lists Submenu**_          |                           |
| &nbsp; &nbsp; Parent Folders              | Cmd + 1                   |
| &nbsp; &nbsp; History                     | Cmd + 2                   |
| &nbsp; &nbsp; Favorites                   | Cmd + 3                   |
| &nbsp; &nbsp; Volumes                     | Cmd + 4                   |
| &nbsp; &nbsp; Connections                 | Cmd + 5                   |
| &nbsp; &nbsp; Tags                        | Cmd + 6                   |
| &nbsp; Go To Folder...                    | Shift + Cmd + G           |
| &nbsp; _**Connect To Submenu**_           |                           |
| &nbsp; &nbsp; FTP Server...               |                           |
| &nbsp; &nbsp; SFTP Server...              |                           |
| &nbsp; &nbsp; WebDAV Server...            |                           |
| &nbsp; &nbsp; Dropbox Storage...          |                           |
| &nbsp; &nbsp; Network Share...            |                           |
| &nbsp; &nbsp; Manage Connections...       |  Cmd + K                  |

### External Editors
_to be written_

### External Tools
_to be written_

### Syntax Highlighting
_to be written_

## Advanced

### Command-line Options
_to be written_

### File Locations
_to be written_

### Admin Mode
_to be written_

### Logging
_to be written_

## Frequently Asked Questions

**Q**: I have an idea for Nimble Commander!  
**A**: That’s fantastic! Feel free to contribute your ideas. The entire source code and build instructions for Nimble Commander are available in [this repository](https://github.com/mikekazakov/nimble-commander). Be sure to read through the [CONTRIBUTING](https://github.com/mikekazakov/nimble-commander/blob/main/CONTRIBUTING.md) guidelines carefully before you start.

---

**Q**: Nimble Commander crashes/behaves incorrectly/etc. Can you fix it?  
**A**: Possibly. However, it is often difficult to track down the problem without a detailed description of the setup and a set of reproducible steps. Please spend some time describing in detail what happened and how it can be reproduced. This will greatly help in resolving the issue.

---

**Q**: Can you implement a specific feature or request?  
**A**: Likely not. As Nimble Commander is maintained by a single contributor, resources are limited, and I cannot accommodate all requests due to time and energy constraints. However, contributions from the community are welcome. You can consider implementing the feature yourself. Check out the [contribution guidelines](https://github.com/mikekazakov/nimble-commander/blob/main/CONTRIBUTING.md) for more information.

---

**Q**: Preview lacks a feature XYZ, is it possible to add it?  
**A**: This might be challenging. The entire preview functionality is managed by macOS via the [Quick Look framework](https://en.wikipedia.org/wiki/Quick_Look). Rendition and behaviour for various file types is provided by various plugins in that system-wide framework, and Nimble Commander has no control over it. Currently it doesn’t even have any content-specific logic. While it’s possible to start providing special handling for some specific file types, like images, it would require significant resources to implement, test, and maintain.

---

**Q**: Can Nimble Commander access iCloud storage?  
**A**: Nimble Commander does not provide first-class access to iCloud. Apple does not have an official API to allow applications to directly manipulate items outside of their own containers. At least that’s my understanding of the status quo at the moment of writing (I’d be glad to be proven wrong). However, you can manually navigate to `~/Library/Mobile Documents/com~apple~CloudDocs` and access the items there using the normal UI of Nimble Commander. This usually works, but there is no guarantee that the content of that folder is properly synchronized.

---

**Q**: Nimble Commander crashes with EXC_BAD_INSTRUCTION.  
**A**: This has been observed when macOS Catalina is installed on hardware that is not officially supported. Nimble Commander/x64 requires SSE4.2 since v1.2.9, which is available on all Mac models officially supported by Catalina. If this OS version is installed on a machine with a CPU lacking these instructions, Nimble Commander v1.2.9+ cannot run. The only workaround is to use an older version.

---

**Q**: How can I download a previous version?
**A**: All previous releases are available here: [https://github.com/mikekazakov/nimble-commander-releases](https://github.com/mikekazakov/nimble-commander-releases)

---

**Q**: Do you plan to add capabilities to modify existing archives?  
**A**: There are no plans to add this feature at the moment unless someone steps up to implement it. The reasons why were discussed here: [https://magnumbytes.com/forum/viewtopic.php?f=6&t=205](https://magnumbytes.com/forum/viewtopic.php?f=6&t=205)

---

**Q**: How to make Nimble Commander restore the state of its windows after it has been closed and restarted?  
**A**: Turn off the checkbox `System Settings > Desktop & Dock > Close windows when quitting an application`. By default, this option is turned on.

---

**Q**: Where does Nimble Commander store its state?  
**A**: In these locations:

- Main configuration files (managed by NC):  
`~/Library/Application Support/Nimble Commander/Config`
- Volatile state file (managed by NC):  
`~/Library/Application Support/Nimble Commander/State`
- Windows state (managed by macOS):  
`~/Library/Saved Application State/info.filesmanager.Files.savedState`
- Application defaults (managed by macOS):  
`~/Library/Preferences/info.filesmanager.Files.plist`
- Admin Mode helper binary (managed by macOS):  
`/Library/PrivilegedHelperTools/info.filesmanager.Files.PrivilegedIOHelperV2`
- Admin Mode helper configuration (managed by macOS):  
`/Library/LaunchDaemons/info.filesmanager.Files.PrivilegedIOHelperV2.plist`
