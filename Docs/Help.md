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
![sandbox permissions](Help-sandbox-perm.png)

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
_to be written_
