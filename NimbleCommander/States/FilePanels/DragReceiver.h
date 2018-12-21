// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <VFS/VFS.h>
#include <Cocoa/Cocoa.h>

@class PanelController;
@class FilesDraggingSource;

namespace nc::panel {

// STA design - use in the main thread only
class DragReceiver
{
public:
    DragReceiver(PanelController *_target,
                 id <NSDraggingInfo> _dragging,
                 int _dragging_over_index); // -1 index means "whole" panel
    ~DragReceiver();

    NSDragOperation Validate();
    bool Receive();
    static NSArray<NSString*> *AcceptedUTIs();

private:
    VFSPath ComposeDestination() const;
    std::pair<NSDragOperation, int> ScanLocalSource(FilesDraggingSource *_source,
                                                const VFSPath& _dest) const;
    std::pair<NSDragOperation, int> ScanURLsSource(NSArray<NSURL*> *_source,
                                              const VFSPath& _dest) const;
    std::pair<NSDragOperation, int> ScanURLsPromiseSource(const VFSPath& _dest) const;
    NSDragOperation BuildOperationForLocal(FilesDraggingSource *_source,
                                           const VFSPath &_destination ) const;
    NSDragOperation BuildOperationForURLs(NSArray<NSURL*> *_source,
                                          const VFSPath &_destination ) const;
    bool PerformWithLocalSource(FilesDraggingSource *_source,
                                const VFSPath& _dest);
    bool PerformWithURLsSource(NSArray<NSURL*> *_source,
                               const VFSPath& _dest);
    bool PerformWithURLsPromiseSource(const VFSPath& _dest);

    PanelController     *m_Target;
    id<NSDraggingInfo>   m_Dragging;
    NSDragOperation      m_DraggingOperationsMask;
    int                  m_DraggingOverIndex;
    VFSListingItem       m_ItemUnderDrag; // may be nullptr for whole panel
    bool                 m_DraggingOverDirectory;
};

}
