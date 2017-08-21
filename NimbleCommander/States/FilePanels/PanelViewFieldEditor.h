#pragma once

@interface NCPanelViewFieldEditor : NSScrollView<NSTextViewDelegate>

- (instancetype)initWithFilename:(const string&)_filename;
- (void)markNextFilenamePart;

@property (nonatomic, readonly) NSTextView *textView;
@property (nonatomic, readonly) const string &originalFilename;
@property (nonatomic) void (^onTextEntered)(const string &_new_filename);
@property (nonatomic) void (^onEditingFinished)();

@end
