//
//  FileOp.h
//  Directories
//
//  Created by Michael G. Kazakov on 26.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <sys/dirent.h>
#include <dispatch/queue.h>

@class MainWindowController;

class AbstractFileJob
{
public:
    AbstractFileJob();
    virtual ~AbstractFileJob() = 0;
    
    double Done() const;
    bool IsReadyToPurge() const;
    double BytesPerSecond() const;
    
protected:
    void SetDone(double _val);
    void SetReadyToPurge();
    void SetBytesPerSecond(double _val);
private:
    double m_Done; // [0..1]
    double m_BytesPerSecond; // process speed if available. zero by default, can vary by operation type
    bool   m_ReadyToPurge;
    AbstractFileJob(const AbstractFileJob&); // forbid such things
    void operator=(const AbstractFileJob&);  // forbid such things
};

class FileCopy : public AbstractFileJob
{
public:
    FileCopy();
    ~FileCopy();
    
    void InitOpData(const char *_src, const char *_dest, MainWindowController *_wnd);
    void Run();

private:
    void DoRun();
    void DoCleanup();
    char m_SrcPath[__DARWIN_MAXPATHLEN];
    char m_DestPath[__DARWIN_MAXPATHLEN];
    int  m_SrcFD;
    int  m_DestFD;
    MainWindowController *m_Wnd;
    void *m_Buffer1;
    void *m_Buffer2;
    
};

