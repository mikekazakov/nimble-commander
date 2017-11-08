//
//  GTMHotKeyTextField.h
//
//  Copyright 2006-2010 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License.  You may obtain a copy
//  of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
//  License for the specific language governing permissions and limitations under
//  the License.
//

// Text field for capturing hot key entry. This is intended to be similar to the
// Apple key editor in their Keyboard pref pane.

// NOTE: There are strings that need to be localized to use this field.  See the
// code in stringForKeycode the the keys.  The keys are all the English versions
// so you'll get reasonable things if you don't have a strings file.

#import <Cocoa/Cocoa.h>

@interface GTMHotKey : NSObject <NSCopying>
+ (id)hotKeyWithKey:(NSString *)key
           modifiers:(NSUInteger)modifiers;

+ (GTMHotKey*) emptyHotKey;


//- (id)initWithKeyCode:(NSUInteger)keyCode
//            modifiers:(NSUInteger)modifiers;

- (id)initWithKey:(NSString *)str
         modifiers:(NSUInteger)modifiers;


// Custom accessors (readonly, nonatomic)
- (bool)isEmpty;

- (NSUInteger)modifiers;
- (NSString *)key;
- (NSString *)visualKey;

@end

//  Notes:
//  - Though you are free to implement control:textShouldEndEditing: in your
//    delegate its return is always ignored. The field always accepts only
//    one hotkey keystroke before editing ends.
//  - The "value" binding of this control is to the dictionary describing the
//    hotkey.
//  - The field does not attempt to consume all hotkeys. Hotkeys which are
//    already bound in Apple prefs or other applications will have their
//    normal effect.
//

@interface GTMHotKeyTextField : NSTextField
@end

@interface GTMHotKeyTextFieldCell : NSTextFieldCell

// Convert Cocoa modifier flags (-[NSEvent modifierFlags]) into a string for
// display. Modifiers are represented in the string in the same order they would
// appear in the Menu Manager.
//
//  Args:
//    flags: -[NSEvent modifierFlags]
//
//  Returns:
//    Autoreleased NSString
//
+ (NSString *)stringForModifierFlags:(NSUInteger)flags;

+ (NSString *)displayStringForHotKey:(GTMHotKey *)hotKey;

- (BOOL)doesKeyCodeRequireModifier:(UInt16)keycode;

@property (readwrite, nonatomic) bool strictModifierRequirement;
@property (strong, nonatomic) GTMHotKey *defaultHotKey;

@end

// Custom field editor for use with hotkey entry fields (GTMHotKeyTextField).
// See the GTMHotKeyTextField for instructions on using from the window
// delegate.
@interface GTMHotKeyFieldEditor : NSTextView

// Get the shared field editor for all hot key fields
+ (GTMHotKeyFieldEditor *)sharedHotKeyFieldEditor;
@property (strong, nonatomic) GTMHotKeyTextFieldCell *cell;

@end
