//
//  Operation.h
//  Directories
//
//  Created by Pavel Dogurevich on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>

class OperationJob;

@interface Operation : NSObject

-(id)initWithJob:(OperationJob *)_job;

-(void)Start;
-(void)Pause;
-(void)Resume;
-(void)Stop;

-(BOOL)IsStarted;

-(BOOL)IsPaused;

// Returns true if the operation finished execution.
-(BOOL)IsFinished;

// Returns true if the operation finished successfully (it completed all required actions).
-(BOOL)IsCompleted;

// Returns true if operation was stopped (it finished before it could complete all required actions).
-(BOOL)IsStopped;

@end
