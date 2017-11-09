/*
     File: DisclosureViewController.m
 Abstract: The main view controller (base view controller) for each view in the NSStackView.
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import <Quartz/Quartz.h>
#import "DisclosureViewController.h"
//@import QuartzCore;   // for kCAMediaTimingFunctionEaseInEaseOut

@interface DisclosureViewController ()
{
    NSView *_disclosedView;
}
@property (weak) IBOutlet NSTextField *titleTextField;      // the title of the discloved view
@property (weak) IBOutlet NSButton *disclosureButton;       // the hide/show button
@property (weak) IBOutlet NSView *headerView;               // header/title section of this view controller

@property (strong) NSLayoutConstraint *closingConstraint;   // layout constraint applied to this view controller when closed

@end


#pragma mark -

@implementation DisclosureViewController
{
    BOOL _disclosureIsClosed;
    NSString *_hideTitle;
    NSString *_showTitle;
}

- (id)init
{
    return [self initWithNibName:@"DisclosureViewController" bundle:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self != nil)
    {
        _disclosureIsClosed = NO;
        _hideTitle = self.disclosureButton.title;
        _showTitle = self.disclosureButton.alternateTitle;
    }
    return self;
}

- (void)awakeFromNib
{
    _disclosureIsClosed = NO;
        _hideTitle = self.disclosureButton.title;
        _showTitle = self.disclosureButton.alternateTitle;

}

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    [self.titleTextField setStringValue:title];
}

- (NSView *)disclosedView
{
    return _disclosedView;
}

- (void)setDisclosedView:(NSView *)disclosedView
{
    if (_disclosedView != disclosedView)
    {
        [self.disclosedView removeFromSuperview];
        _disclosedView = disclosedView;
        
        [self.view addSubview:self.disclosedView];
        
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_disclosedView]|"
                                                                          options:0
                                                                          metrics:nil
                                                                            views:NSDictionaryOfVariableBindings(_disclosedView)]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_headerView][_disclosedView]"
                                                                          options:0
                                                                          metrics:nil
                                                                            views:NSDictionaryOfVariableBindings(_headerView, _disclosedView)]];
        
        // add an optional constraint (but with a priority stronger than a drag), that the disclosing view
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_disclosedView]-(0@600)-|"
                                                                          options:0 metrics:nil
                                                                            views:NSDictionaryOfVariableBindings(_disclosedView)]];
    }
}

// The hide/show button was clicked
//
- (IBAction)toggleDisclosure:(id)sender
{
    if (!_disclosureIsClosed)
    {
        CGFloat distanceFromHeaderToBottom = NSMinY(self.view.bounds) - NSMinY(self.headerView.frame);

        if (!self.closingConstraint)
        {
            // The closing constraint is going to tie the bottom of the header view to the bottom of the overall disclosure view.
            // Initially, it will be offset by the current distance, but we'll be animating it to 0.
            self.closingConstraint = [NSLayoutConstraint constraintWithItem:self.headerView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1 constant:distanceFromHeaderToBottom];
        }
        self.closingConstraint.constant = distanceFromHeaderToBottom;
        [self.view addConstraint:self.closingConstraint];
    
        if( self.view.window )
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                // Animate the closing constraint to 0, causing the bottom of the header to be flush with the bottom of the overall disclosure view.
                self.closingConstraint.animator.constant = 0;
                self.disclosureButton.title = _showTitle;
            } completionHandler:^{
                _disclosureIsClosed = YES;
                _disclosedView.hidden = YES;
            }];
        else {
            self.closingConstraint.constant = 0;
            self.disclosureButton.title = _showTitle;
            _disclosureIsClosed = YES;
            _disclosedView.hidden = YES;
        }
    }
    else
    {
        if( self.view.window )
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                // Animate the constraint to fit the disclosed view again
                self.closingConstraint.animator.constant -= self.disclosedView.frame.size.height;
                self.disclosureButton.title = _hideTitle;
                _disclosedView.hidden = NO;
            } completionHandler:^{
                // The constraint is no longer needed, we can remove it.
                [self.view removeConstraint:self.closingConstraint];
                _disclosureIsClosed = NO;
            }];
        else {
            self.disclosureButton.title = _hideTitle;
            [self.view removeConstraint:self.closingConstraint];
            _disclosureIsClosed = NO;
            _disclosedView.hidden = NO;
        }
    }
}

@end
