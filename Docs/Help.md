# Nimble Commander Help

## Getting Started

### Introduction

Nimble Commander is a free dual-pane file manager for macOS, designed with a focus on speed, keyboard-based navigation, and flexibility. The project aims to blend the user experience of classic file managers from the '80s and '90s with the modern look and feel of Mac computers. Nimble Commander follows the design principles of [orthodox file managers](https://en.wikipedia.org/wiki/File_manager#Orthodox_file_managers), specifically dual-pane file managers. This website contains an in-depth study of this kind of software: [Less is More: Orthodox File Managers as Sysadmin IDE](https://softpanorama.org/OFM/index.shtml).

### System Requirements

Nimble Commander supports any Mac running the following versions of macOS:

- macOS 10.15 Catalina
- macOS 11 Big Sur
- macOS 12 Monterey
- macOS 13 Ventura
- macOS 14 Sonoma

It runs natively on both Intel and Arm architectures.

### Installation

Nimble Commander is portable; it doesn't require the installation of additional components and can run from any folder. When downloaded from the Mac App Store, Nimble Commander is automatically placed in the `/Applications` folder. If it was downloaded from the website, it can be copied into the `/Applications` folder by dragging the icon there. You can also run Nimble Commander directly from a `.dmg` disk image; in this case, Nimble Commander will offer to move itself to the `/Applications` folder.

![Copying NC from a dmg](Help-install-dmg.png)

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
Below is a screenshot of a typical interface of Nimble Commander:

![Example of the interface](Help-main-ui.png)

The main window is typically split vertically between the two panels. Sometimes these panels are called panes; both words will be used interchangeably later on. Only one panel is active at a time, which is indicated by highlighting. To change the active panel, you can click on the desired panel or use hotkeys:

- `Tab`: focuses on the opposite panel
- `Shift + Cmd + Left`: focuses on the left panel
- `Shift + Cmd + Right`: focuses on the right panel

The proportion between the left and right panels can be changed by either dragging a vertical separator line or by using the hotkeys: `Ctrl + Alt + Left` and `Ctrl + Alt + Right`. A panel can also be collapsed entirely so that only one is visible. This can be achieved by changing the width proportion until one panel is completely removed or by using the hotkey `Shift + Cmd + P`, which toggles between dual-pane and single-pane modes.

Each panel is vertically divided into three logical parts:

- Header: contains the path of the current location and the indicator of the sorting mode.
- File items: displays a list of the file items in the location of this panel.
- Footer: shows the filename of the focused item, its size and modification date, the total number of items in the panel, and the free space available on this storage.

### Navigation
Nimble Commander supports both mouse-based and keyboard-based navigation inside the file panel, although the keyboard is preferred. Use a single mouse click to change the cursor position (i.e., the focused item) and scroll gestures to scroll through the contents of the file panel without changing the cursor position. The navigation hotkeys are the following:

- `Up`: moves the cursor up
- `Down`: moves the cursor down
- `Left`: moves the cursor left
- `Right`: moves the cursor right
- `Home`: moves the cursor to the first element
- `Opt + Home`: scrolls the contents to the first element
- `End`: moves the cursor to the last element
- `Opt + End`: scrolls the contents to the last element
- `Page Up`: moves the cursor to the previous page
- `Opt + Page Up`: scrolls the contents to the previous page
- `Page Down`: moves the cursor to the next page
- `Opt + Page Down`: scrolls the contents to the next page

To navigate to a different folder inside the file panel, either double-click on it or press `Return` when the folder is focused. To go to a parent folder, do the same with the `..` [pseudo-folder](https://en.wikipedia.org/wiki/Path_(computing)#Representations_of_paths_by_operating_system_and_shell) located at the beginning of the items. Displaying the `..` folder is optional and can be turned off in the Settings dialog. Pressing `Backward Delete` (Backspace) or `Cmd + Up` navigates to the parent folder, regardless of the current cursor position.

Nimble Commander stores location history for each file panel. To navigate the history back and forth, use the `Cmd + [` and `Cmd + ]` hotkeys.

There are some locations that can be navigated to using hotkeys:

- `/`: Root of the filesystem
- `~` and `Shift + Cmd + H`: Home folder
- `Shift + Cmd + O`: Documents folder
- `Shift + Cmd + D`: Desktop folder
- `Opt + Cmd + L`: Downloads folder
- `Shift + Cmd + A`: Applications folder
- `Shift + Cmd + U`: Utilities folder

To navigate to a commonly used location, you can use the Go To popup, which can be opened by pressing the `F1` / `F2` hotkey or via the menu: `Go > Left Panel...` / `Go > Right Panel...`. This popup provides quick access to favorite locations, volumes, connections, and locations of other panels. Elements of this popup have hotkeys associated with them in the order of appearance: `0`, `1`, ..., `9`, `0`, `-`, `=`. Any text typed while the Go To popup is open will act as a filter, hiding locations that do not contain the typed text in their names.  Once you click on the selected location, the panel will navigate there and become focused if it wasn’t already. Here is what the popup looks like:

![GoTo popup](Help-goto-popup.png)

To navigate to an arbitrary location on the filesystem, you can use the GoTo dialog opened by the `Shift + Cmd + G` hotkey or through the menu: `Go > Go To Folder...`. In this dialog, you can type any path, and after clicking the Go button Nimble Commander will navigate to the specified folder. Below is the view of this dialog box:

![GoTo dialog](Help-goto-dialog.png)

If the cursor is currently pointing to a file that is a symbolic link, the `Cmd + Right` hotkey can be used to navigate to the location the symlink points to.

### Panel Management
You can swap the contents of the left and right panels using the `Cmd + U` hotkey or the menu item `View > Swap Panels`. This operation also transfers the focus to the opposite panel.  
To sync the contents of the opposite panel with the contents of the current panel, you can use the `Opt + Cmd + U` hotkey or the menu item `View > Sync Panels`.  
In most cases, Nimble Commander will automatically refresh the contents of the file panel whenever the underlying part of the filesystem changes. Sometimes, however, it's not possible to automatically detect these changes. In such cases, the panel can be manually refreshed using the `Cmd + R` hotkey or the menu item `View > Refresh`.

The two panels in a Nimble Commander's window normally have the same width. If needed this proportion can be changed by either dragging the splitter located between them or by using the `Ctrl + Opt + Left` / `Ctrl + Opt + Right` hotkeys. Here is an example of panels with different widths:

![Panels proportion](Help-panel-proportion.png)

A panel can be collapsed entirely, turning the UI into single-pane mode. This can also be done via the  `Shift + Cmd + P` hotkey or the `View > Toggle Single-Pane Mode` menu item. To return to dual-pane mode, expand the collapsed panel the same way it was previously collapsed, or use the `Shift + Cmd + P` hotkey or the `View > Toggle Dual-Pane Mode` menu item. The following screenshot provides an example of how single-pane mode looks:

![Single-pane mode](Help-panel-collapsed.png)

### Selection
Nimble Commander follows the UX of orthodox file managers and diverges from the typical MacOS UX when it comes to item selection. It treats item selection and cursor position separately, which means moving the cursor does not change the selection of items in the panel. Below is an example of a panel with some selected items and the cursor focused on an item that is not selected:

![Items selection](Help-panel-selection.png)

There are numerous ways to manipulate the item selection using the keyboard or mouse in Nimble Commander:

- `Cmd + A`: selects all items.
- `Opt + Cmd + A`: deselects all items.
- `Ctrl + Cmd + A`: inverts the selection.
- `Shift + Up` / `Shift + Down`: inverts the selection of the currently focused item before moving the cursor. The behaviour (selection or deselection) is determined when the `Shift` key is pressed and persists while it is held down.
- `Shift + Cursor Movement`: changes the selection within the range starting at the current cursor position and ending at the new cursor position. The selection is inverted depending on the state of the initially focused item: if it was not selected, the entire range will be selected; if it was already selected, the whole range will be deselected.
- `Enter`: inverts the selection of the currently focused item and moves the cursor to the next item.
- `Cmd + Click`: inverts the selection of the clicked item.
- `Cmd + =`: selects all items with a filename matching the specified file mask or regular expression.
- `Cmd + -`: deselects all items with a filename matching the specified file mask or regular expression.
- `Alt + Cmd + =`: selects all items with the same extension as the currently focused item.
- `Alt + Cmd + -`: deselects all items with the same extension as the currently focused item.

### Sorting Modes
Nimble Commander offers various ways to organize items in a folder.
You can sort the items in ascending or descending order based on the following properties:

- Name
- Extension
- Size
- Modified Time
- Created Time
- Added Time
- Accessed Time

A letter indicator in the top-left corner of the file panel shows the current sorting criteria:

| Indicator | Criteria        | Order           | Example
| --------- | --------------- | --------------- | ---------
| `n`       | Name            | Ascending       | a ... z
| `N`       | Name            | Descending      | z ... a
| `e`       | Extension       | Ascending       | csv ... zip
| `E`       | Extension       | Descending      | zip ... csv
| `s`       | Size            | Descending      | 10 MB ... 1 MB
| `S`       | Size            | Ascending       | 1 MB ... 10 MB
| `m`       | Modified Time   | Descending      | 20:43 ... 18:15
| `M`       | Modified Time   | Ascending       | 18:15 ... 20:43
| `b`       | Created Time    | Descending      | 20:43 ... 18:15
| `B`       | Created Time    | Ascending       | 18:15 ... 20:43
| `a`       | Added Time      | Descending      | 20:43 ... 18:15
| `A`       | Added Time      | Ascending       | 18:15 ... 20:43
| `x`       | Accessed Time   | Descending      | 20:43 ... 18:15
| `X`       | Accessed Time   | Ascending       | 18:15 ... 20:43

This is an example of the sorting pop-up menu shown after clicking on the sorting indicator:

![Sorting pop-up](Help-panel-sorting.png)

You can change the sorting order by clicking on the indicator and selecting a new option in the pop-up menu, by using the menu `View > Sorting`, by clicking the column headers in List View mode, or via the following hotkeys:

- `Ctrl + Cmd + 1`: Sort by Name.
- `Ctrl + Cmd + 2`: Sort by Extension.
- `Ctrl + Cmd + 3`: Sort by Modified Time.
- `Ctrl + Cmd + 4`: Sort by Size.
- `Ctrl + Cmd + 5`: Sort by Creation Time.
- `Ctrl + Cmd + 6`: Sort by Added Time.
- `Ctrl + Cmd + 7`: Sort by Accessed Time.

When changing the sorting order via hotkeys or the menu, the behavior depends on the previous sorting order. If the criteria are different, it will switch to the selected criteria with its default order (as shown in the table above). 
Selecting the same sorting criteria again will toggle the order between ascending and descending.

Nimble Commander also provides some customization options to fine-tune sorting:

- `Separate Folders from Files` places all folders before any regular files.
- `Extensionless Folders` forces extension-based sorting to treat any folder as if it doesn't have an extension.
- `Comparison` affects how filenames are compared when determining the order:
  - `Natural`: takes into account locale-specific collation rules and treats digits as numbers. This is the same ordering used by Finder and approximately follows the [Unicode collation algorithm](https://en.wikipedia.org/wiki/Unicode_collation_algorithm). The slowest of the three.
  - `Case-Insensitive`: A Unicode-based comparison that ignores the case of letters in filenames.
  - `Case-Sensitive`:  A simple Unicode-based comparison that compares characters one by one without transformations. The fastest of the three.

### Quick Search

Nimble Commander offers a fast way to locate a file in a folder by typing a few letters from its name. This keyboard-based navigation is called Quick Search. It's highly customizable and can behave differently based on your settings, but at its core, the idea is simple: any keyboard input can be used to filter folder items. To remove the filtering, press the `Esc` button to clear the search query.

Quick Search underscores the items with matching filenames and offers two ways to handle non-matching items: either continue showing them or hide them from the listing. This behavior can be changed in the `Settings` dialog: `Panel > Quick Search > When searching`: `Show all items` or `Show only matching items`. The following screenshot shows how Quick Search filters out all items except the two that match the input query 'color':

![Quick search](Help-panel-quicksearch.png)

An optional key modifier can be specified so that only keypresses with the chosen modifier will be registered as input for Quick Search. There are 5 different options for the modifiers that can be chosen in `Panel > Quick Search > Key modifier`:

- `Opt`
- `Ctrl + Opt`
- `Shift + Opt`
- `No modifier` (default)
- `Disabled` (turns off Quick Search altogether)

The input query can be interpreted in different ways. There are 5 options for matching filenames against it, configurable in `Panel > Quick Search > Where to search`:

- `Fuzzy`: Letters from the input query must appear anywhere in the filename, in the same order.
- `Anywhere` (default): The input query must appear as a whole anywhere in the filename.
- `Beginning`: The filename must start with the input query.
- `Ending`: The filename must end with the input query.
- `Beginning or ending`: The filename must start or end with the input query.

When filtered-out items are configured to still be shown, and a key modifier is set, it can be used to lock navigation within the matching files. Using normal keyboard navigation (Arrows, Home, End, etc.) while holding the modifier will restrict the cursor movement to only the matching files.

### View Modes
_to be written_

### Quick Lists
_to be written_

### Tabs
_to be written_

### Favorites
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

| Action                                       | Key Equivalent            |
| -----------------------------------------    | ------------------------- |
| _**Nimble Commander Menu**_                  |                           |
| &nbsp; About                                 |                           |
| &nbsp; Preferences                           | Cmd + ,                   |
| &nbsp; Enable Admin Mode                     |                           |
| &nbsp; Hide Nimble Commander                 | Cmd + H                   |
| &nbsp; Hide Others                           | Opt + Cmd+H               |
| &nbsp; Show All                              |                           |
| &nbsp; Quit Nimble Commander                 | Cmd + Q                   |
| &nbsp; Quit and Close All Windows            | Opt + Cmd + Q             |
| _**File Menu**_                              |                           |
| &nbsp; New Window                            | Cmd + N                   |
| &nbsp; New Folder                            | Shift + Cmd + N           |
| &nbsp; New Folder with Selection             | Ctrl + Cmd + N            |
| &nbsp; New File                              | Opt + Cmd + N             |
| &nbsp; New Tab                               | Cmd + T                   |
| &nbsp; Enter                                 | Return                    |
| &nbsp; Open                                  | Shift + Return            |
| &nbsp; Reveal in Opposite Panel              | Opt + Return              |
| &nbsp; Reveal in Opposite Panel Tab          | Opt + Cmd + Return        |
| &nbsp; Paste Filename to Terminal            | Ctrl + Opt + Return       |
| &nbsp; Paste Filenames to Terminal...        | Ctrl + Opt + Cmd + Return |
| &nbsp; Calculate Folders Sizes               | Shift + Opt + Return      |
| &nbsp; Calculate All Folders Sizes           | Ctrl + Shift + Return     |
| &nbsp; Duplicate                             | Cmd + D                   |
| &nbsp; Add to Favorites                      | Cmd + B                   |
| &nbsp; Close                                 | Cmd + W                   |
| &nbsp; Close Window                          | Shift + Cmd + W           |
| &nbsp; Close Other Tabs                      | Opt + Cmd + W             |
| &nbsp; Find...                               | Cmd + F                   |
| &nbsp; Find with Spotlight...                | Opt + Cmd + F             |
| &nbsp; Find Next                             | Cmd + G                   |
| _**Edit Menu**_                              |                           |
| &nbsp; Copy                                  | Cmd + C                   |
| &nbsp; Paste                                 | Cmd + V                   |
| &nbsp; Move Item Here                        | Opt + Cmd + V             |
| &nbsp; Select All                            | Cmd + A                   |
| &nbsp; Deselect All                          | Opt + Cmd + A             |
| &nbsp; Invert Selection                      | Ctrl + Cmd + A            |
| _**View Menu**_                              |                           |
| &nbsp; Toggle Single-Pane Mode               | Shift + Cmd + P           |
| &nbsp; Swap Panels                           | Cmd + U                   |
| &nbsp; Sync Panels                           | Opt + Cmd + U             |
| &nbsp; _**View Mode Submenu**_               |                           |
| &nbsp; &nbsp; Toggle Short View Mode         | Ctrl + 1                  |
| &nbsp; &nbsp; Toggle Medium View Mode        | Ctrl + 2                  |
| &nbsp; &nbsp; Toggle Full View Mode          | Ctrl + 3                  |
| &nbsp; &nbsp; Toggle Wide View Mode          | Ctrl + 4                  |
| &nbsp; &nbsp; Toggle View Mode V             | Ctrl + 5                  |
| &nbsp; &nbsp; Toggle View Mode VI            | Ctrl + 6                  |
| &nbsp; &nbsp; Toggle View Mode VII           | Ctrl + 7                  |
| &nbsp; &nbsp; Toggle View Mode VIII          | Ctrl + 8                  |
| &nbsp; &nbsp; Toggle View Mode IX            | Ctrl + 9                  |
| &nbsp; &nbsp; Toggle View Mode X             | Ctrl + 0                  |
| &nbsp; _**Sorting Submenu**_                 |                           |
| &nbsp; &nbsp; Sort By Name                   | Ctrl + Cmd + 1            |
| &nbsp; &nbsp; Sort By Extension              | Ctrl + Cmd + 2            |
| &nbsp; &nbsp; Sort By Modified Time          | Ctrl + Cmd + 3            |
| &nbsp; &nbsp; Sort By Size                   | Ctrl + Cmd + 4            |
| &nbsp; &nbsp; Sort By Creation Time          | Ctrl + Cmd + 5            |
| &nbsp; &nbsp; Sort By Added Time             | Ctrl + Cmd + 6            |
| &nbsp; &nbsp; Sort By Accessed Time          | Ctrl + Cmd + 7            |
| &nbsp; &nbsp; Separate Folders From Files    |                           |
| &nbsp; &nbsp; Extensionless Folders          |                           |
| &nbsp; &nbsp; Natural Comparison             |                           |
| &nbsp; &nbsp; Case-Insensitive Comparison    |                           |
| &nbsp; &nbsp; Case-Sensitive Comparison      |                           |
| &nbsp; Show Hidden Files                     | Shift + Cmd + .           |
| &nbsp; _**Panels Position Submenu**_         |                           |
| &nbsp; &nbsp; Move Left                      | Ctrl + Opt + Left         |
| &nbsp; &nbsp; Move Right                     | Ctrl + Opt + Right        |
| &nbsp; &nbsp; Move Up                        | Ctrl + Opt + Up           |
| &nbsp; &nbsp; Move Down                      | Ctrl + Opt + Down         |
| &nbsp; &nbsp; Show Panels                    | Ctrl + Opt + O            |
| &nbsp; &nbsp; Focus Overlapped Terminal      | Ctrl + Opt + Tab          |
| &nbsp; Show Tab Bar                          | Shift + Cmd + T           |
| &nbsp; Show Toolbar                          | Opt + Cmd + T             |
| &nbsp; Show Terminal                         | Opt + Cmd + O             |
| _**Go Menu**_                                |                           |
| &nbsp; Left Panel...                         | F1                        |
| &nbsp; Right Panel...                        | F2                        |
| &nbsp; Back                                  | Cmd + [                   |
| &nbsp; Forward                               | Cmd + ]                   |
| &nbsp; Enclosing Folder                      | Cmd + Up                  |
| &nbsp; Enter                                 | Cmd + Down                |
| &nbsp; Follow                                | Cmd + Right               |
| &nbsp; Documents                             | Shift + Cmd + O           |
| &nbsp; Desktop                               | Shift + Cmd + D           |
| &nbsp; Downloads                             | Opt + Cmd + L             |
| &nbsp; Home                                  | Shift + Cmd + H           |
| &nbsp; Library                               |                           |
| &nbsp; Applications                          | Shift + Cmd + A           |
| &nbsp; Utilities                             | Shift + Cmd + U           |
| &nbsp; Root                                  |                           |
| &nbsp; Processes List                        | Opt + Cmd + P             |
| &nbsp; _**Favorites Submenu**_               |                           |
| &nbsp; &nbsp; Manage Favorites...            | Ctrl + Cmd + B            |
| &nbsp; _**Recently Closed Submenu**_         |                           |
| &nbsp; &nbsp; Restore Last Closed Panel      | Shift + Cmd + R           |
| &nbsp; _**Quick Lists Submenu**_             |                           |
| &nbsp; &nbsp; Parent Folders                 | Cmd + 1                   |
| &nbsp; &nbsp; History                        | Cmd + 2                   |
| &nbsp; &nbsp; Favorites                      | Cmd + 3                   |
| &nbsp; &nbsp; Volumes                        | Cmd + 4                   |
| &nbsp; &nbsp; Connections                    | Cmd + 5                   |
| &nbsp; &nbsp; Tags                           | Cmd + 6                   |
| &nbsp; Go To Folder...                       | Shift + Cmd + G           |
| &nbsp; _**Connect To Submenu**_              |                           |
| &nbsp; &nbsp; FTP Server...                  |                           |
| &nbsp; &nbsp; SFTP Server...                 |                           |
| &nbsp; &nbsp; WebDAV Server...               |                           |
| &nbsp; &nbsp; Dropbox Storage...             |                           |
| &nbsp; &nbsp; Network Share...               |                           |
| &nbsp; &nbsp; Manage Connections...          | Cmd + K                   |
| _**Command Menu**_                           |                           |
| &nbsp; System Overview                       | Cmd + L                   |
| &nbsp; Detailed Volume Information           |                           |
| &nbsp; File Attributes                       | Ctrl + A                  |
| &nbsp; Open Extended Attributes              | Opt + Cmd + X             |
| &nbsp; Copy Item Name                        | Shift + Cmd + C           |
| &nbsp; Copy Item Path                        | Opt + Cmd + C             |
| &nbsp; Copy Item Directory                   | Shift + Opt + Cmd + C     |
| &nbsp; Select With Mask                      | Cmd + =                   |
| &nbsp; Select With Extension                 | Opt + Cmd + =             |
| &nbsp; Deselect With Mask                    | Cmd + -                   |
| &nbsp; Deselect With Extension               | Opt + Cmd + -             |
| &nbsp; Preview                               | Cmd + Y                   |
| &nbsp; Internal Viewer                       | Opt + F3                  |
| &nbsp; External Editor                       | F4                        |
| &nbsp; Eject Volume                          | Cmd + E                   |
| &nbsp; Batch Rename...                       | Ctrl + M                  |
| &nbsp; Copy To...                            | F5                        |
| &nbsp; Copy As...                            | Shift + F5                |
| &nbsp; Move To...                            | F6                        |
| &nbsp; Move As...                            | Shift + F6                |
| &nbsp; Rename In Place                       | Ctrl + F6                 |
| &nbsp; Create Directory                      | F7                        |
| &nbsp; Move To Trash                         | Cmd + Backward Delete     |
| &nbsp; Delete...                             | F8                        |
| &nbsp; Delete Permanently...                 | Shift + F8                |
| &nbsp; Compress...                           | F9                        |
| &nbsp; Compress To...                        | Shift + F9                |
| &nbsp; _**Links Submenu**_                   |                           |
| &nbsp; &nbsp; Create Symbolic Link           |                           |
| &nbsp; &nbsp; Create Hard Link               |                           |
| &nbsp; &nbsp; Edit Symbolic Link             |                           |
| _**Window Menu**_                            |                           |
| &nbsp; Minimize                              | Cmd + M                   |
| &nbsp; Enter Full Screen                     | Ctrl + Cmd + F            |
| &nbsp; Zoom                                  |                           |
| &nbsp; Show Previous Tab                     | Shift + Ctrl + Tab        |
| &nbsp; Show Next Tab                         | Ctrl + Tab                |
| &nbsp; Show VFS List                         |                           |
| &nbsp; Bring All To Front                    |                           |
| _**Special Hotkeys**_                        |                           |
| &nbsp; _**File Panels**_                     |                           |
| &nbsp; &nbsp; Move Up                        | Up                        |
| &nbsp; &nbsp; Move Down                      | Down                      |
| &nbsp; &nbsp; Move Left                      | Left                      |
| &nbsp; &nbsp; Move Right                     | Right                     |
| &nbsp; &nbsp; Move to the First Element      | Home                      |
| &nbsp; &nbsp; Scroll to the First Element    | Opt + Home                |
| &nbsp; &nbsp; Move to the Last Element       | End                       |
| &nbsp; &nbsp; Scroll to the Last Element     | Opt + End                 |
| &nbsp; &nbsp; Move to the Next Page          | Page Down                 |
| &nbsp; &nbsp; Scroll to the Next Page        | Opt + Page Down           |
| &nbsp; &nbsp; Move to the Previous Page      | Page Up                   |
| &nbsp; &nbsp; Scroll to the Previous Page    | Opt + Page Up             |
| &nbsp; &nbsp; Toggle Selection               |                           |
| &nbsp; &nbsp; Toggle Selection and Move Down | Enter                     |
| &nbsp; &nbsp; Change Active panel            | Tab                       |
| &nbsp; &nbsp; Previous Tab                   | Shift + Cmd + [           |
| &nbsp; &nbsp; Next Tab                       | Shift + Cmd + ]           |
| &nbsp; &nbsp; Go into Enclosing folder       | Backward Delete           |
| &nbsp; &nbsp; Go into Folder                 |                           |
| &nbsp; &nbsp; Go to Home Folder              | Shift + ~                 |
| &nbsp; &nbsp; Go to Root Folder              | /                         |
| &nbsp; &nbsp; Show Preview                   | Space                     |
| &nbsp; &nbsp; Show Tab №1                    |                           |
| &nbsp; &nbsp; Show Tab №2                    |                           |
| &nbsp; &nbsp; Show Tab №3                    |                           |
| &nbsp; &nbsp; Show Tab №4                    |                           |
| &nbsp; &nbsp; Show Tab №5                    |                           |
| &nbsp; &nbsp; Show Tab №6                    |                           |
| &nbsp; &nbsp; Show Tab №7                    |                           |
| &nbsp; &nbsp; Show Tab №8                    |                           |
| &nbsp; &nbsp; Show Tab №9                    |                           |
| &nbsp; &nbsp; Show Tab №10                   |                           |
| &nbsp; &nbsp; Focus Left Panel               | Shift + Cmd + Left        |
| &nbsp; &nbsp; Focus Right Panel              | Shift + Cmd + Right       |
| &nbsp; _**Viewer**_                          |                           |
| &nbsp; &nbsp; Toggle Text                    | Cmd + 1                   |
| &nbsp; &nbsp; Toggle Hex                     | Cmd + 2                   |
| &nbsp; &nbsp; Toggle Preview                 | Cmd + 3                   |
| &nbsp; &nbsp; Show GoTo                      | Cmd + L                   |
| &nbsp; &nbsp; Refresh                        | Cmd + R                   |

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

**Q**: Can I see folders which are starting with dot (for example, ".folder")?  
**A**: Yes, it’s possible to see hidden folders. Toggle this option by selecting `Menu > View > Show Hidden Files` or by pressing `Shift + Cmd + .`.

---

**Q**: Can I open an archive which has an improper extension (for example. .xlsx, .pak etc)?  
**A**: Yes, an archive with an improper extension can be opened by selecting `Menu > Go > Enter`, or by using the hotkey `Cmd + Down`.

---

**Q**: Do dialogs in Nimble Commander have hotkeys?  
**A**: Yes, many dialogs have hotkeys using the Ctrl (^) key modifier. Hovering the mouse cursor over a UI element will display context help, which may show the hotkey for that element.

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
