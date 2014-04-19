//
//  ClassicPanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 06.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelViewPresentation.h"
#import "OrthodoxMonospace.h"
#import "ObjcToCppObservingBridge.h"
#import "VFS.h"

class FontCache;
@class PanelView;

class ClassicPanelViewPresentation : public PanelViewPresentation
{
public:
    ClassicPanelViewPresentation();
    
    void Draw(NSRect _dirty_rect) override;
    void OnFrameChanged(NSRect _frame) override;
    
    NSRect GetItemColumnsRect() override;
    int GetItemIndexByPointInView(CGPoint _point) override;
    
    int GetNumberOfItemColumns() override;
    int GetMaxItemsPerColumn() override;
    
    int Granularity();
    
    double GetSingleItemHeight() override;
    
private:
    void BuildGeometry();
    void BuildAppearance();
    void DrawWithShortMediumWideView(CGContextRef _context);
    void DrawWithFullView(CGContextRef _context);
    const DoubleColor& GetDirectoryEntryTextColor(const VFSListingItem &_dirent, bool _is_focused);
    
    NSSize          m_FrameSize;
    int             m_SymbWidth = 0;
    int             m_SymbHeight = 0;
    shared_ptr<FontCache> m_FontCache;
    DoubleColor     m_BackgroundColor;
    DoubleColor     m_CursorBackgroundColor;
    DoubleColor     m_RegularFileColor[2];
    DoubleColor     m_DirectoryColor[2];
    DoubleColor     m_HiddenColor[2];
    DoubleColor     m_SelectedColor[2];
    DoubleColor     m_OtherColor[2];
    ObjcToCppObservingBlockBridge *m_GeometryObserver;
    ObjcToCppObservingBlockBridge *m_AppearanceObserver;
};