--> NB! Requires:
--> Settings -> Panel -> Behaviour -> Ignore directories when selecting by mask = OFF
--> Settings -> Panel -> Quick Search -> Where to search = Anywhere

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
    delay 0.2
end moveFocusToDesktop

tell application "System Events"
    tell application "Nimble Commander" to close every window
    tell application "Nimble Commander" to activate

    keystroke "n" using {command down} --> ⌘N - make new window
    delay 0.2

    set position of first window of application process "Nimble Commander" to {100, 100}
    set size of first window of application process "Nimble Commander" to {1220, 740}

    keystroke "h" using {option down, command down} --> ⌥⌘H - hide other windows
    delay 0.2    

    key code 120 --> F2
    delay 0.2
    keystroke "1" --> 1
    delay 0.2
    keystroke "w" using {option down, command down} --> ⌥⌘W    
    delay 0.2
    keystroke "g" using {shift down, command down} --> ⇧⌘G
    delay 0.2
    keystroke "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources"
    delay 0.2
    keystroke return
    delay 0.2
    keystroke "3" using {control down} --> ^3
    keystroke "uni"
    delay 0.2
    key code 119 --> End
    keystroke tab

    keystroke "w" using {option down, command down} --> ⌥⌘W    
    delay 0.2

    keystroke "2" using {control down} --> ^2

    keystroke "g" using {shift down, command down} --> ⇧⌘G
    delay 0.2
    keystroke "/System/Library/CoreServices"
    delay 0.2
    keystroke return
    delay 0.2

    keystroke "=" using {command down} --> ⌘=
    delay 0.2
    keystroke "*.bundle"
    delay 0.2
    keystroke return
    delay 0.2
    keystroke return using {option down, shift down} --> ⌥⇧Return
    delay 1.0
    keystroke "=" using {command down} --> ⌘=
    delay 0.2
    keystroke "*.bundle"
    delay 0.5   
end tell

set ScreenshotName to "Screenshot-2"
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
