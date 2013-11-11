//
//  Operation.h
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OperationDialogProtocol.h"


class OperationJob;
@class OperationDialogController;
@class PanelController;

@interface Operation : NSObject

/**
 * Value from 0 to 1, showing current Operation's progress.
 *
 */
@property (nonatomic) float Progress;

/**
 * Flag that show that Progress not appropriate currently.
 * It is ON by default at is set to OFF when Progress become greater than zero
 */
@property (nonatomic) BOOL IsIndeterminate;

/**
 * Caption of the operation.
 *
 */
@property (nonatomic) NSString *Caption;

/**
 * String with the short information about operation.
 *
 */
@property (nonatomic) NSString *ShortInfo;

/**
 * The paused state of the operation.
 *
 */
@property (nonatomic) BOOL IsPaused;

/**
 * Number of pending dialogs.
 *
 */
@property (nonatomic) int DialogsCount;

/**
 * Panel that caused this operation, or panel that will be affected by this operation. Can be nil.
 *
 */
@property (nonatomic) PanelController* TargetPanel;

- (id)initWithJob:(OperationJob *)_job;

/**
 * Constantly invoked by OperationsController.
 * Operations should update their Progress and Caption properties in this method.
 */
- (void)Update;

- (void)Start;
- (void)Pause;
- (void)Resume;
- (void)Stop;

- (BOOL)IsStarted;

/**
 * Returns true if the operation finished execution.
 */
- (BOOL)IsFinished;

/**
 * Returns true if the operation finished successfully (it completed all required actions).
 */
- (BOOL)IsCompleted;

/**
 * Returns true if operation was stopped (it finished before it could complete all required actions).
 */
- (BOOL)IsStopped;

/**
 * Should be called from job's inner thread.
 */
- (void)EnqueueDialog:(id <OperationDialogProtocol>)_dialog;

- (void)ShowDialog;
- (void)OnDialogClosed:(id <OperationDialogProtocol>)_dialog;


/**
 * OnFinish called by Job on SetCompleted() event.
 */
- (void)OnFinish;

/**
 * Will execute _handler upon succesful finish. It will be exectuted in background thread.
 */
- (void)AddOnFinishHandler:(void (^)())_handler;

- (void) setProgress:(float)Progress;

- (NSString*) ProduceDescriptionStringForBytesProcess;
@end
