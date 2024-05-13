on isRetina()
	set physical to (do shell script "system_profiler SPDisplaysDataType | awk '/Resolution:/{print $2}'")
    set logical to (do shell script "system_profiler SPDisplaysDataType | awk '/UI Looks like:/{print $4}'")
	if physical is equal to logical then
		return false
	else
		return true
	end if
end isRetina

on moveFocusToDesktop()
    tell application "Finder"
	    close every window
        activate
    end tell
end moveFocusToDesktop

tell application "System Events"
    tell application "Nimble Commander" to close every window
    tell application "Nimble Commander" to activate

    keystroke "n" using {command down} --> ⌘N - make new window
    delay 0.2

    set position of first window of application process "Nimble Commander" to {100, 100}
    set size of first window of application process "Nimble Commander" to {1220, 740}

    key code 122 --> F1
    delay 0.2
    keystroke "1" --> 1
    delay 0.2
    keystroke "w" using {option down, command down} --> ⌥⌘W    
    delay 0.2
    keystroke "l" using {option down, command down} --> ⌥⌘V
    delay 0.2
    keystroke "t" using {command down} --> ⌘T
    delay 0.2
    keystroke "o" using {shift down, command down} --> ⇧⌘O
    delay 0.2
    keystroke "t" using {command down} --> ⌘T
    delay 0.2
    keystroke tab using {control down} --> ^tab
    delay 0.2
    keystroke tab using {control down} --> ^tab
    delay 0.2
    keystroke "g" using {shift down, command down} --> ⇧⌘G
    delay 0.2
    keystroke "/Applications/Xcode_15_1_0.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include"
    delay 0.2
    keystroke return
    delay 0.2
    keystroke "3" using {control down} --> ^3
    delay 0.2
    keystroke "_ctype"
    delay 0.2
    key code 53 --> Esc
    delay 0.2
    key code 126 --> Up
    key code 126 --> Up
    key code 126 --> Up
    key code 126 --> Up
    key code 126 --> Up
    key code 126 --> Up
    delay 0.2

    keystroke tab --> tab
    delay 0.2
    keystroke "w" using {option down, command down} --> ⌥⌘W    
    delay 0.2
    keystroke "d" using {shift down, command down} --> ⇧⌘D
    delay 0.2
    keystroke "t" using {command down} --> ⌘T
    delay 0.2
    keystroke "g" using {shift down, command down} --> ⇧⌘G
    delay 0.2
    keystroke "/System/Library"
    delay 0.2
    keystroke return
    delay 0.2
    keystroke "1" using {control down} --> ^1
    delay 0.2
    keystroke "CacheDelete"
    delay 0.2
    key code 53 --> Esc
    delay 0.2
    key code 125 using {shift down} --> ⇧Down
    key code 125 using {shift down} --> ⇧Down
    key code 125 using {shift down} --> ⇧Down
    key code 125 using {shift down} --> ⇧Down
    key code 125 using {shift down} --> ⇧Down
    key code 125 using {shift down} --> ⇧Down
    key code 125 using {shift down} --> ⇧Down
    delay 0.2
    key code 126 --> Up
    key code 126 --> Up
    key code 126 --> Up
    delay 0.2
    keystroke return using {option down, shift down} --> ⌥⇧Return
    delay 1.0

    keystroke tab --> tab
    delay 0.2

    keystroke "h" using {option down, command down} --> ⌥⌘H - hide other windows
    delay 0.2
end tell

set ScreenshotName to "Screenshot-1"
set ScreenshotOffset to "+30+30"
if isRetina() then
    set ScreenshotName to ScreenshotName & "@2x"
    set ScreenshotOffset to "+60+60"
end if

set ScreenshotWithoutShadows to ScreenshotName & "_without_shadows.png"
set ScreenshotWithShadows to ScreenshotName & "_with_shadows.png"
set ScreenshotFinal to ScreenshotName & ".png"
tell application "Nimble Commander" to set windowID to id of window 1
do shell script "screencapture -x -o -tpng -l " & windowID & " " & ScreenshotWithoutShadows
moveFocusToDesktop()

do shell script "screencapture -x -R70,70,1280,800 -tpng " & ScreenshotWithShadows

do shell script "gm composite -geometry " & ScreenshotOffset & " " & ScreenshotWithoutShadows & " " & ScreenshotWithShadows & " " & ScreenshotFinal

do shell script "rm " & ScreenshotWithoutShadows
do shell script "rm " & ScreenshotWithShadows
