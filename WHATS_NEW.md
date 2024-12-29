# What's New in Nimble Commander

## Version 1.7.0 (18 Dec 2024)
- Updated for macOS Sequoia.
- The integrated viewer now provides syntax highlighting using the Lexilla library.
- The integrated viewer no longer uses toolbars; instead, a status bar is used to save space.
- The user guide has been significantly expanded.
- Updated the application icon.
- Added an option for natural collation when sorting filenames.
- Fixed a bug causing unstable ordering of tool icons on the toolbar.
- The "Go To" popup now allows numeric keys to filter items.
- Added a new hotkey: Ctrl+Return to display a context menu.
- Fixed an issue with incomplete FTP transfers.
- Fixed an issue where an overlapped terminal caused the mouse cursor to display the wrong type.
- Fixed a broken Shift+Tilde shortcut.
- Removed the built-in checksum calculation feature.
- Cmd+B now adds the current directory of a panel instead of the path to the currently focused item.
- Fixed an issue where excessive refresh requests during file operations caused incorrect behavior in file panels.
- Numerous small UI polish improvements have been made.

## Version 1.6.1 (23 Jul 2024)
- Improved the security checks in the privileged helper.

## Version 1.6.0 (14 May 2024)
- Nimble Commander is now completely free and open source.
- Added support for file tags.
- Fixed an issue that could stop directory updates on SMB volumes.
- Fixed an issue where the mouse cursor could navigate to the wrong directory.
- You can now extract files from archives by dragging them into the ".." directory.
- Fixed an issue where file permissions might not be restored correctly after extracting from an archive.
- Fixed a crash when accessing an FTP server.
- Fixed keyboard navigation issues with F1/F2 and Quick Lists pop-ups.
- Fixed a bug preventing correct duplication of a file that's being written to.

## Version 1.5.0 (18 Dec 2023)
- Updated for macOS Sonoma.
- Added support for italic text in the terminal emulator.
- Added support for the DECSCUSR command by the terminal emulator.
- Added full support for 8-bit colours and partial support for 24-bit colours in the terminal emulator.
- Added support for escaping of square brackets in batch renaming: [[ and ]].
- Added support for fuzzy matching in Quick Search.
- Improved the cancellation of panel refreshing.
- Improved the handling of RAR archives.
- Improved the support of complex Unicode symbols by the terminal emulator.
- Improved the arguments parsing for the external tools.
- Fixed the mapping of new the functional keys on M2 laptops.
- Fixed the incorrect behaviour of the hotkey input field.
- Fixed an issue that the overlapped terminal could sometimes stop syncing the current working directory.
- Fix a crash that could happen when dragging from a temporary panel.
- Many other fixes, improvements and optimizations.

## Version 1.4.0 (25 Dec 2022)
- Updated for macOS Ventura.
- Now supports opening compressed non-archived files with these extensions: .bz2, .gz, .lz, .lz4, .lzma, .lzo, .xz, .z, .zst.
- Find Files and (De-)Select by Mask now both support masks based on regular expressions.
- Reformatted the UI of the Find Files dialog to make it more laconic.
- Themes are now following the current macOS appearance, automatically switching between the two selected themes whenever the system-wide appearance changes. That's configurable and can be disabled. By default, the built-in "Light" and "Dark" themes are selected.
- Added two new hotkeys: Shift+Cmd+Left/Right to focus the left/right panel.
- Now scrolling caused by keypresses is instantaneous by default for both Brief and List presentation modes. The "filePanel.presentation.smoothScrolling" config setting controls this behaviour.
- Batch Rename now picks a longest filename to select a range of characters from.
- Improved the robustness of in-place renaming, that fixes the situations when a filesystem change discarded the in-place editor.
- Improved the robustness of the filesystem notifications handling. Now NC tries to rely on system notifications whenever possible but also keeps a backup in case the events don't come.
- Now switching to a Single-Pane mode and then back to Dual-Pane mode preserves the proportion between the panels.
- Fixed an issue with moving items into the ".." directory.
- Fixed a performance degradation when calculating directories sizes in a massive listing.
- Fixed an issue with dragging a file into NC when a Full Disk Access was not granted, which could end up in an error.
- Fixed an issue with incorrect horizontal alignment of a scroller in the Brief presentation mode.
- Fixed the visual glitches in the Dark mode caused by transparency of the List view headers.
- Cmd-Backspace no longer moves an item to Trash when its being renamed via in-place filename editor.
- Fixed a visual glitch of wrongly truncated filenames being when they could fit entirely.
- Fixed an issue with WebDAV that the MOVE request wasn't conforming to the RFC and could fail on some servers.
- Fixed an issue that cloud-based file providers caused huge resources consumption when browsing these directories.
- Improved the consistency of the custom hotkeys handling. Now non-menu actions rely on hotkey characters instead of key codes as previously.
- Fixed an issue with the built-in terminal that is didn't support custom shells that are relative symlinks.
- Fixed a visual glitch when Brief Mode wasn’t displaying items until manually scrolled.
- Fixed a sporadic deadlock in the native VFS happened when setting up listeners to notifications of the filesystem events.
- Fixed a QuickLook crash when switching between some PDF files.
- Fixed a UI crash that could happen when filenames contain newline symbols.
- Many other fixes, improvements and optimizations.

## Version 1.3.0 (16 Oct 2021)
- List view now has the Extension and the Date Accessed columns.
- Items can now be sorted by Date Last Opened a.k.a. "atime".
- Built-in Viewer now does scrolling along a predominant axis only.
- Built-in Viewer can now update its content by Cmd+R or automatically on native filesystems.
- Brief System information now shows additional info in the CPU and the RAM boxes.
- Quick Search no longer handles the Space key by default.
- The Backspace key can now be assigned to any file panel shortcut.
- Batch Rename now supports the [P] and the [G] placeholders for parent and grandparent directory names.
- Batch Rename now supports text processing for the [A] placeholder.
- Now the toolbar tries to resolve full paths for short names of command-line tools to show their icons.
- Move to Trash can now work in Admin Mode.
- Added an option to choose which file operations should be enqueued and which should always start immediately.
- A generic error dialog shown by file operations can now implicitly mark the "Apply to All" checkbox if Shift is pressed.
- Locked items can now be unlocked by file operations.
- Stability of the WebDAV VFS was improved.
- Dropbox VFS now uses short-lived access tokens.
- Fixed a crash when an External Tool asks for a parameter value.
- Fixed a crash when in-place renaming was used in combination with Quick Search.
- Fixed an issue that Quick Search prompt was not updated when a panel was reloaded.
- Fixed an issue that in-place renaming could remove focus from a current panel.
- Fixed an issue with saving the configuration when the Users folder was placed on a non-root volume.
- Fixed an issue with the built-in terminal when a custom shell was a symbolic link.
- Fixed an issue with the inability of PSFS VFS to kill a process.
- Fixed an issue of silent failing to drag an item into an NC window when lacking permissions.
- Fixed a visual glitch with vertical separators when Classic theme was used.
- Fixed a visual glitch of blurred panels after switching between Retina and Non-Retina displays.
- Fixed a freeze in the Batch Rename dialog when renaming a large number of items.
- Many other improvements and optimizations.

## Version 1.2.9 (31 Dec 2020)
- Now contains a universal binary for ARM64 and x86-64.
- Updated for macOS Big Sur.
- Terminal emulator was significantly improved.
- Panel items are now automatically deselected after a file operation.
- Added a new action “Follow Symlink”: Cmd+Right.
- Fixed defaults paths to system applications.
- Fixed support for large directories in Dropbox VFS.
- Now a Deletion operation can be stopped during a scanning phase.
- Now file time representations are updated when a system date changes.
- Preview request now automatically expands a collapsed panel.
- SFTP VFS now supports ED25519 keys.
- FTP VFS now supports Active Mode.
- Numerous other bug fixes and improvements.

## Version 1.2.8 (18 Apr 2020, MAS only)
- Fixed an issue of slow renaming.

## Version 1.2.7 (29 Jan 2020)
- Updated to support macOS Catalina.
- Bugfixes and internal improvements.

## Version 1.2.6 (24 Aug 2019)
- Internal Viewer got a new implementation which is more performant and stable.
- Compress operation now provides an option to protect a target archive with a password.
- Find Files sheet got an option to search for files which do not contain some text.
- New action “Copy Item Directory”: Shift+Alt+Cmd+C.
- QuickLook icons are now generated only for files with extensions conforming to a whitelist of UTIs. By default, this list includes “public.image”, “public.movie” and “public.audio”.
- Popup menus (F1/F2 and quick lists: Cmd+1..5) can now switch to other menus by hitting their hotkeys.
- Dragging items to the Trash now deletes them as expected.
- The in-place renaming editor now flickers less and is more responsive.
- Fixed an issue with incompatible SSH key types.
- Fixed the built-in terminal’s issue of invalid scroll position after switching to file panels and back.
- Fixed an issue with an invalid placing of the Sharing popup.
- Lots of other bugfixes and internal improvements.

## Version 1.2.5 (27 Nov 2018)
- Updated to support macOS Mojave.
- Copy/Move operation can now keep both items when a destination already exists.
- File panels can now restore their saved states synchronously to reduce flicker on window creation.
- Field rename editor now commits an edit when its window loses focus.
- New action: “Close Other Tabs” (Alt+Cmd+W).
- The “+” button on the tab bar now reacts on the right click the same way as on the long press.
- Improved unmounting of APFS volumes. Now NC will eject an underlying physical storage too.
- Lots of bugfixes and internal improvements.
            
## Version 1.2.4 (27 Feb 2018)
- Added an ability to restore recently closed tabs via Shift+Cmd+R hotkey, or via Go->Recently Closed menu or via Plus button on the tab bar.
- Temporary panels are now stored in navigation history.
- Fixed the issue with APFS performance when copying large files.
- Fixed the issue with directories overwriting by moving.
- SFTP now supports falling back to rm+mv when a remote server refuses to perform an overwriting rename command.
- Fixed an issue of reporting an invalid size in temporary panels under certain conditions.
- Quick Search now allows arrow navigation inside matching results when it shows all items.
- Esc button can now return a window from full screen mode.

## Version 1.2.3 (12 Dec 2017)
- Improved UI for hotkeys customization.
- Now supporting Preview as a floating window.
- Selected items now have a highlighted background.
- Added support for dragging panel tabs between left and right sides.
- Sync Panels action now supports cloning of a temporary panel.
- Improved navigation with Alt+Arrows/Shift+Alt+Arrows in controls with filenames.
- Now clicking on a selected tab of a non-active pane will activate it.
- Improved the performance of SFTP operations.
- Fixed the issue with symlinks handling during the Copy operation.
- Fixed the issue with hidden symlinks being shown on certain conditions.
- Fixed the issue with QuickLook failure when the Classic theme is selected.
- Fixed the issue with wrong timestamps after copying to an SMB mount.

## Version 1.2.2 (19 Sep 2017)
- Added a new VFS: WebDAV.
- Made some enhancements for APFS and macOS High Sierra compatibility.
- SFTP now supports changing of file attributes and creation of symbolic links.
- File operations UI has got a much clearer design.
- Added notifications support.
- Made many improvements in drag & drop functionality.
- “Copy As” file operation now focuses the resulting item.
- Progress indicator in Dock is now much easier to read.
- Show Hidden Files shortcut was changed to “Shift+Cmd+.”.
- Fixed the lack of undo/redo when doing an in-place item renaming.
- Fixed the issue with invalid item icons in virtual file systems.

## Version 1.2.1 (29 May 2017)
- Added a new VFS: Dropbox.
- Added support for mounting of network shares.
- Added the network connections management window.
- Added a customizable favorite locations list.
- “Favorites” pop-up now has a section with frequently visited locations.
- Navigation pop-ups now support a quick selection by keyboard typing.
- “Duplicate” command is now accessible via the main menu or via the Cmd+D hotkey.

## Version 1.2.0 (4 Mar 2017)
- General UI overhaul: File panels presentation was rewritten from scratch.
- File panels can now be scrolled without cursor movement.
- Added customizable file panel layouts.
- File columns can now have dynamic width.
- Added a new feature: Themes.
- Added Dark Mode support.
- Sort mode indicator in the top-left corner became a button with a pop-up options list.
- Added the file icon size option: 1x, 2x, or disabled.
- Thumbnail generation now respects HiDPI displays.
- When using Quick Search, the “Show only matching items” option is now selected by default.
- Quick Search now underscores query matches in file names.
- Improved saving and restoring of window states.
- Added cascading of new windows.
- All alert windows can now be controlled with arrow keys.
- Improved drag & drop functionality.
- Fixed the issue with Ctrl+Tab processing.
- Date Added column is now shown in Full view mode.
- Added new hotkeys to scroll the file panel without moving the cursor: Alt+Home, Alt+End, Alt+PageUp, Alt+PageDown.
- Shift+Cmd+C/Alt+Cmd+C now copies file names/paths of all selected items.
- When working with FTP, Cmd+R forces the VFS to reload a directory listing.
- Fixed stability issues with SFTP connections.
- Added support for .xz archives.
- Allowed opening of partially damaged archives.
- Added automatic encoding detection when working with archives.
- Volumes are now properly ejected after being unmounted.
- OS X 10.10 is no longer supported.

## Version 1.1.5 (30 Sep 2016)
- Now the Find Files dialog can peek into archives.
- Made various UI improvements to the Find Files dialog.
- Now Internal Viewer can be shown in a separate window.
- Added support for archive handling on any VFS (that is, in other archives, on network filesystems, etc.).
- Added a startup mode setting for external tools.
- Now the terminal shell can be customized. Three shells are supported: bash, zsh, and [t]csh.
- If the shell was terminated (via exit, ^D, etc.), NC can revive it.
- Assigned “Compress Here” to F9, and “Compress to Opposite Panel” to Shift+F9.
- Now the File Already Exists dialog treats a pressed Shift key as an automatic “Apply to All”.
- Now toolbars can be customized.
- Now consequent Ctrl+F6 hits switch the selection between the filename without the extension, the file extension, and the whole filename.
- Added a new customizable hotkey: “Invert current item selection”.
- Batch Rename: Now source items can be removed via the context menu or by using the backspace key.
- Made many other improvements concerning usability, performance, and stability.

## Version 1.1.4 (30 July 2016)
- MAS-only maintenance update.

## Version 1.1.3 (27 July 2016)
- Added External Tools integration support: Quickly open any application with a variety of parameters based on the current focus/selection/path, etc.
- Added a new option to overwrite older files during a copy or move operation.
- Now External Editors can be used with any virtual file system, and changed files will be uploaded back.
- Added the new ⇧⌘P shortcut to toggle single-pane or dual-pane mode.
- Now deleting a file with process information in PSFS (Processes List) will kill that process.
- Added access to F1 … F19 buttons regardless of system settings.
- Enabled scripting with AppleScript.
- Now in case of drag & drop within NC, it will check whether the source and target filesystems are the same. Based on that information, NC will choose between moving and copying. Of course, the keyboard modifiers (Ctrl for linking, Alt for copying, Cmd for moving) will be considered, too.
- Added new shortcuts: F9 to compress items in the target panel, and ⇧F9 to compress items in the current panel.
- Fixed the issue with unmountable volumes (for example, USB flash drives that were locked by the built-in terminal and could not be ejected).
- Built-in terminal will no longer produce error messages on USB sticks with FAT32.
- Made some improvements in the handling of symbolic links inside archives.
- Fixed some visual and stability bugs.

## Version 1.1.2 (7 June 2016)
- Changed the application’s title to Nimble Commander.
- Added basic support for editing remote files.
- Added support for lightweight search with Spotlight.
- Added the new ⌥⌘V shortcut to move item here.
- Added support for remapping the main navigation keys.
- Fixed the problem of connecting to SSH-less SFTP servers.
- Fixed the issue with changing the case when renaming folders.
- Made some improvements in the FindFiles panel’s UI.
- Made lots of other minor fixes and improvements.

## Version 1.1.1 (14 March 2016)
- Added a new editable JSON-based config.
- Added ability to save and restore file panels states.
- Now extension-based sorting follows the case-sensitivity option.
- Now file search shows the current search path.
- Added basic support for encrypted Zip archives.
- Added text selection in the terminal emulator by double- and triple-clicking.
- Added different filenames trimming options.
- Added the ^F6 shortcut to rename an item in place.
- Added the ⌥⌘↩ shortcut to open an item in opposite panel tab.
- Fixed many bugs and did many other improvements.

## Version 1.1.0 (2 December 2015)
- Added ability to display search results as a temporary file panel.
- Added ability to modify the extended attributes (xattr) with the ⌥⌘X hotkey, like usual files.
- Added copy verification with MD5 checksum checking.
- Added quick selection/deselection by extension: ⌥⌘- / ⌥⌘=.
- Added ability to work as NSFileViewer.
- Now Enter opens a file as an archive only if the file has an appropriate extension.
- Fixed many bugs and did many other improvements, including huge code refactoring.
- OS X 10.9 is no longer supported.

## Version 1.0.9 (31 August 2015)
- Added the “overlapped” built-in terminal mode.
- Added the blinking cursor in the terminal.
- Added automatic version update mechanism.
- Added navigation quick lists with ⌘1-⌘5.
- Added support for archiving folders with symlinks.
- Improved drag & drop.
- Improved stability and performance.

## Version 1.0.8 (25 June 2015)
- Added the Batch Rename feature.
- Added an option to hide a scrollbar in the terminal.
- Added the ~ shortcut to go to Home directory.
- Added the / shortcut to go to Root directory.
- Fixed window size changing after switching to terminal or viewer mode.
- Did optimizations and fixed minor bugs.

## Version 1.0.7 (28 April 2015)
- Updated the look in modern presentation mode.
- Now a network connection can have an arbitrary title.
- Now recent network connections are shown in the GoTo pop-up menu.
- Added ability to edit or remove network connections in the Connect To menu by pressing the ⇧ or ⌥ key.
- Updated the Go To Folder sheet with autocomplete.
- Added empty file creation with the ⌥⌘N hotkey.
- OS X 10.8 is no longer supported.
- Fixed bugs and did other improvements.

## Version 1.0.6 (18 February 2015)
- Added support for Zip64 and WARC archives.
- Fixed connectivity issues when using the OS X built-in SFTP server.
- Fixed bugs and did minor improvements.

## Version 1.0.5 (23 January 2015)
- Added ability to save remote connections.
- Added Russian translation.
- Added checking of Trash availability in a volume.
- Now a single backspace is treated as Go to Enclosing Folder.
- Improved stability.
- OS X 10.7 is no longer supported.

## Version 1.0.4 (12 December 2014)
- Added the admin mode (requires OS X 10.10).
- Added support for key-based SFTP authentication.
- Added the “Invert selection” hotkey: ^⌘A.
- Added more tab selection hotkeys: ⇧⌘[ and ⇧⌘].
- Fixed bugs and did other improvements.

## Version 0.6.3 (21 November 2014)
- Added support for tabs.
- Added file size display options.
- Added support for symlinks in archives.
- Improved stability and performance.

## Version 0.6.2 (27 October 2014)
- Updated the application to be compatible with OS X Yosemite.
- Added file checksum calculation.
- Added history in the Find Files sheet.
- Improved drag & drop.
- Added the “New folder” hotkey: ⇧⌘N.
- Added the “New folder with items” hotkey: ^⌘N.
- Now the space key opens preview.
- Now the bundles preview works with archives/FTP/SFTP.
- Fixed bugs.

## Version 0.6.1 (6 September 2014)
- Added support for SFTP.
- Added simplified quick search and files selecting by mask.
- Improved stability and performance.

## Version 0.6.0 (7 August 2014)
- Added support for FTP.
- Added custom filenames coloring based on filters.

## Version 0.5.9 (10 July 2014)
- Improved Unicode support in classic panel presentation and terminal emulator.
- Added ability to load the file encoding setting from the com.apple.TextEncoding extended attribute.
- Added the option to show localized filenames.
- Added keyboard shortcut editing in the Preferences window.
- Changed panel sorting hotkeys to ^⌘1-^⌘5.
- Added the “Eject volume” hotkey: ⌘E.
- Now by default QuickSearch works without key modifiers.
- Fixed minor bugs.

## Version 0.5.8 (19 June 2014)
- Added in-place files renaming by mouse click.
- Added terminal settings customization.
- Added new hotkeys for panels proportion changing: ^← / ^→ and ^⌥← / ^⌥→.

## Version 0.5.7 (25 May 2014)
- Added icons and thumbnails caching for smooth navigation.
- Added virtual file system with processes list and corresponding information.
- Fixed drag & drop of multiple files in some applications.
- Added the “Open directory in opposite panel” hotkey: ⌥↩.
- Did many stability and performance improvements.

## Version 0.5.6 (22 April 2014)
- Added support for integration of external editors, both native apps and terminal ones.
- Added Volume Information bar which displays a free space.
- Added ability to cancel opening of a big file in the internal viewer.
- Improved stability and performance.

## Version 0.5.5 (28 March 2014)
- Improved RAR archives support.
- Added calculation of all subdirectories’ sizes with the ^⇧↩ hotkey.
- Now directory contents are re-sorted by size after subdirectory size calculation.
- Added a hotkey to invert selection of the current item and move to the next one: Insert (fn↩).
- Slightly changed the look of the toolbar.
- Added the ⌥⌘T hotkey to show/hide the toolbar.
- Now a progress bar is shown in the application’s dock icon during file operations.
- Now the attention dialog opens if a problem occurs when a file operation starts.
- Now the internal viewer can also be closed with the hotkey used for opening it: ⌥F3.
- Fixed invalid coloring in terminal sessions and occasional problems with some binaries.
- Fixed many bugs and did stability improvements.

## Version 0.5.4 (28 February 2014)
- Added file search with options for filename mask, size, and contained text.
- Now toolbars can be hidden.
- Added support for the editable menu’s keyboard shortcuts via ~/Library/Application Support/Files/shortcuts.plist configuration file with defaults stored in ShortcutsDefaults.plist.

## Version 0.5.3 (9 February 2014)
- Added drag & drop support.

## Version 0.5.2 (20 January 2014)
- Added quick search options for soft/hard filtering and modifier keys.
- Fixed bugs and did minor improvements.

## Version 0.5.1 (30 December 2013)
- Added the ⌘⌫ shortcut to quickly move files to Trash.
- Added the ⌥⇧↩ shortcut to calculate directories’ sizes.
- Added the ⌥⇧⌘I shortcut to show/hide invisible files.
- Now invisible files are grayed in modern presentation mode.
- Added the Go submenu offering a set of standard folders with shortcuts.
- Added the ⇧⌘G shortcut to invoke the Go To Folder sheet.
- Added history navigation with ⌘[ and ⌘].
- Now a file panel’s Go To menu is invoked with F1 / F2 instead of ⌥F1 / ⌥F2.
- Now the Go To menu shows the same items as in Finder’s Favorites.
- Now the Go To menu items have quick-access hotkeys: 1, 2, … ,9, 0, -, =.
- Improved stability and performance.

## Version 0.5.0 (17 December 2013)
- Added a built-in terminal emulator.

## Version 0.4.4 (14 November 2013)
- Added a context menu to file panel items.
- Did minor improvements.

## Version 0.4.3 (31 October 2013)
- Added compression support: ability to archive files to the Zip format.
- Improved stability and performance.

## Version 0.4.2 (19 October 2013)
- Added the “Share” button for quick sharing of files and folders.
- Now panels proportion can be changed by dragging the splitter.
- Now QuickLook is integrated into the main window.
- Added the “Brief System Overview” pane.

## Version 0.4.1 (3 October 2013)
- Added pasteboard support: using ⌘C/⌘C to copy/paste files across the system.
- Added a hotkey to copy the currently selected entry name/path.
- Added a hotkey to go to the upper directory.
- Added an option to include other windows’ paths into the GoTo menu.
- Added the internal viewer’s search options and recent searches history.
- Implemented smooth scrolling in the internal viewer.
- Improved stability and performance.

## Version 0.4.0 (19 September 2013)
- Added archive browsing support: opening, viewing (with the internal viewer or QuickLook), and copying files from archives like from regular folders.
- Added support for the following formats: zip, tar, bz2, gz, pax, cpio, lha, ar, cab, mtree, iso, rar.
- Now the application can open archives regardless of their extension, including docx, xlsx, etc.
- Did minor performance improvements.

## Version 0.3.2 (15 August 2013)
- Added a tooltip widget for fast file searching (when typing with the ⌥ button).
- Added ability to fine-tune file copying (advanced settings).
- Added an option for numeric file sorting.
- Now the GoTo buttons display icons for folders.
- Added support for file selection by mask/wildcard.
- Now the internal text/hex viewer can save selection in the file.
- Now the size of the “..” directory can be calculated with F3, like in other cases.
- Added a volume eject/unmount button in the main window.
- Added a new preferences window with many customization options.
- Improved stability and performance.

## Version 0.3.1 (6 July 2013)
- Added support for link handling: creating symlinks and hardlinks, editing existing symlinks.
- Did lots of internal viewer enhancements: history saving, per-word and per-line selection, right shift+click handling, selection in hexadecimal mode, and more.

## Version 0.3.0 (23 June 2013)
- Added a built-in file viewer with textual and hexadecimal data presentation, capable of handling even multi-gigabyte files.
- Fixed minor bugs and did minor improvements.

## Version 0.2.0 (24 May 2013)
- Added a new presentation mode.
- Added support for Mac OS X 10.7.
- Did lots of minor improvements.

## Version 0.1.0 (1 May 2013)
-  Initial release.
