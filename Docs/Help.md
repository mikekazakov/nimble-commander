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

| Action                            | Key Equivalent |
| --------------------------------- | -------------- |
| _Nimble Commander Menu_           |                |
| &nbsp; About                      |                |
| &nbsp; Preferences                | Cmd+,          |
| &nbsp; Enable Admin Mode          |                |
| &nbsp; Hide Nimble Commander      | Cmd+H          |
| &nbsp; Hide Others                | Alt+Cmd+H      |
| &nbsp; Show All                   |                |
| &nbsp; Quit Nimble Commander      | Cmd+Q          |
| &nbsp; Quit and Close All Windows | Alt+Cmd+Q      |
| _File Menu_                       |                |
| &nbsp; New Window                 | Cmd+N          |
| &nbsp; New Folder                 | Shift+Cmd+N    |
| &nbsp; New Folder with Selection  | Ctrl+Cmd+N     |
| &nbsp; New File                   | Alt+Cmd+N      |
| &nbsp; New Tab                    | Cmd+T          |

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
**A**: Great, please feel free to go ahead and implement it! The entire source code and build instructions for Nimble Commander are available in [this repository](https://github.com/mikekazakov/nimble-commander). Though make sure to read through [CONTRIBUTING](https://github.com/mikekazakov/nimble-commander/blob/main/CONTRIBUTING.md) carefully.

---

**Q**: Nimble Commander crashes/behaves incorrectly/etc. Can you fix it?  
**A**: Probably. However, often is hard to impossible to track the problem down without a detailed description of a setup and a set of reproducible steps. So if you'd like this issue to be fixed - please, spend some time describing in details what has happened and how that could be reproduced.

---

**Q**: Can you implement a _specific feature or request_?  
**A**: Likely no. As Nimble Commander is maintained by a single contributor, the resources are rather limited, and I'm not able to accommodate all requests due to time and energy constraints. However, contributions from the community are welcome and you could consider getting involved in implementing the feature yourself. Check out the [contribution guidelines](https://github.com/mikekazakov/nimble-commander/blob/main/CONTRIBUTING.md) for more information.

---

**Q**: Preview lacks a feature XYZ, is it possible to add it?  
**A**: Likely not so easy. The entire preview functionality is managed by macOS via the [Quick Look framework](https://en.wikipedia.org/wiki/Quick_Look). Rendition and behaviour for various file types is provided by various plugins in that system-wide framework, and Nimble Commander has nothing to do with it. Currently it doesn’t even have any content-specific logic. While it’s possible to start providing special handling for some specific file types, e.g. images, it would require significant resources investment to implement, cover with tests and maintain.

---

**Q**: Can Nimble Commander access iCloud storage?  
**A**: NC does not provide a first-class citizen access to iCloud. The reason is that Apple doesn’t have an official API to allow applications to directly manipulate items outside of their own containers. At least that’s my understanding of the status quo at the moment of writing (I’d be glad to be proven wrong). Having said that, it’s possible to manually navigate into `~/Library/Mobile Documents/com~apple~CloudDocs` and access the items there using the normal UI of NC. This usually works, however there’s no guarantee that content of that folder is properly synchronised.

---

**Q**: NC crashes with EXC_BAD_INSTRUCTION.  
**A**: This was observed when macOS Catalina was installed on hardware that is not officially supported. NC/x64 requires SSE4.2 since v1.2.9, which is available on all Mac models officially supported by Catalina. But if this OS version was installed on a machine with a CPU without these instructions, NC v1.2.9+ simply cannot run. The only possible workaround is using an older version.

---

**Q**: How to download a previous version?  
**A**: All previous releases are available here: [https://github.com/mikekazakov/nimble-commander-releases](https://github.com/mikekazakov/nimble-commander-releases)

---

**Q**: Do you plan to add capabilities to modify existing archives?  
**A**: There are no such plans at the moment, unless somebody wants to step up and roll out a sound implementation of the feature. The seasons why were discussed here: [https://magnumbytes.com/forum/viewtopic.php?f=6&t=205](https://magnumbytes.com/forum/viewtopic.php?f=6&t=205)

---

**Q**: How to make Nimble Commander restore the state of its windows after it has been closed and restarted?  
**A**: Turn off the checkbox `System Settings > Desktop & Dock > Close windows when quitting an application`, by default it is On.

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
