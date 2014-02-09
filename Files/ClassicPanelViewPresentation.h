//
//  ClassicPanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 06.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelViewPresentation.h"
#import "OrthodoxMonospace.h"
#import "VFS.h"

class FontCache;
@class PanelView;
struct DirectoryEntryInformation;
@class ObjcToCppObservingBridge;

class ClassicPanelViewPresentation : public PanelViewPresentation
{
public:
    ClassicPanelViewPresentation();
    ~ClassicPanelViewPresentation();
    
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
    static void OnAppearanceChanged(void *_obj, NSString *_key_path, id _objc_object, NSDictionary *_changed, void *_context);
    static void OnGeometryChanged(void *_obj, NSString *_key_path, id _objc_object, NSDictionary *_changed, void *_context);
    void DrawWithShortMediumWideView(CGContextRef _context);
    void DrawWithFullView(CGContextRef _context);
    const DoubleColor& GetDirectoryEntryTextColor(const VFSListingItem &_dirent, bool _is_focused);
    
    NSSize          m_FrameSize;
    int             m_SymbWidth;
    int             m_SymbHeight;
    FontCache      *m_FontCache;
    DoubleColor     m_BackgroundColor;
    DoubleColor     m_CursorBackgroundColor;
    DoubleColor     m_RegularFileColor[2];
    DoubleColor     m_DirectoryColor[2];
    DoubleColor     m_HiddenColor[2];
    DoubleColor     m_SelectedColor[2];
    DoubleColor     m_OtherColor[2];
    ObjcToCppObservingBridge *m_GeometryObserver;
    ObjcToCppObservingBridge *m_AppearanceObserver;    
};