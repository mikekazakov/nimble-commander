//
//  ModernPanelViewPresentation.cpp
//  Files
//
//  Created by Pavel Dogurevich on 11.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//


#import "ModernPanelViewPresentation.h"

#import "PanelData.h"
#import "Encodings.h"
#import "Common.h"

#import <Quartz/Quartz.h>
#import <deque>
#import <pthread.h>


static void FormHumanReadableBytesAndFiles(unsigned long _sz, int _total_files, UniChar _out[128], size_t &_symbs)
{
    // TODO: localization support
    char buf[128] = {0};
    const char *postfix = _total_files > 1 ? "files" : "file";
#define __1000_1(a) ( (a) % 1000lu )
#define __1000_2(a) __1000_1( (a)/1000lu )
#define __1000_3(a) __1000_1( (a)/1000000lu )
#define __1000_4(a) __1000_1( (a)/1000000000lu )
#define __1000_5(a) __1000_1( (a)/1000000000000lu )
    if(_sz < 1000lu)
        sprintf(buf, "Selected %lu bytes in %d %s", _sz, _total_files, postfix);
    else if(_sz < 1000lu * 1000lu)
        sprintf(buf, "Selected %lu %03lu bytes in %d %s", __1000_2(_sz), __1000_1(_sz), _total_files, postfix);
    else if(_sz < 1000lu * 1000lu * 1000lu)
        sprintf(buf, "Selected %lu %03lu %03lu bytes in %d %s", __1000_3(_sz), __1000_2(_sz), __1000_1(_sz), _total_files, postfix);
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu)
        sprintf(buf, "Selected %lu %03lu %03lu %03lu bytes in %d %s", __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz), _total_files, postfix);
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu * 1000lu)
        sprintf(buf, "Selected %lu %03lu %03lu %03lu %03lu bytes in %d %s", __1000_5(_sz), __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz), _total_files, postfix);
#undef __1000_1
#undef __1000_2
#undef __1000_3
#undef __1000_4
#undef __1000_5
    
    _symbs = strlen(buf);
    for(int i = 0; i < _symbs; ++i) _out[i] = buf[i];
}

static void FormHumanReadableTimeRepresentation14(time_t _in, UniChar _out[14])
{
    struct tm tt;
    localtime_r(&_in, &tt);
    
    char buf[32];
    sprintf(buf, "%2.2d.%2.2d.%2.2d %2.2d:%2.2d",
            tt.tm_mday,
            tt.tm_mon + 1,
            tt.tm_year % 100,
            tt.tm_hour,
            tt.tm_min
            );
    
    for(int i = 0; i < 14; ++i) _out[i] = buf[i];
}

static void FormHumanReadableDateRepresentation8(time_t _in, UniChar _out[8])
{
    struct tm tt;
    localtime_r(&_in, &tt);
    
    char buf[32];
    sprintf(buf, "%2.2d.%2.2d.%2.2d",
            tt.tm_mday,
            tt.tm_mon + 1,
            tt.tm_year % 100
            );
    for(int i = 0; i < 8; ++i) _out[i] = buf[i];
}

static void FormHumanReadableTimeRepresentation5(time_t _in, UniChar _out[5])
{
    struct tm tt;
    localtime_r(&_in, &tt);
    
    char buf[32];
    sprintf(buf, "%2.2d:%2.2d", tt.tm_hour, tt.tm_min);
    
    for(int i = 0; i < 5; ++i) _out[i] = buf[i];
}

// _out will be _not_ null-terminated, just a raw buffer
static void FormHumanReadableSizeRepresentation6(unsigned long _sz, UniChar _out[6])
{
    char buf[32];
    
    if(_sz < 1000000) // bytes
    {
        sprintf(buf, "%6ld", _sz);
    }
    else if(_sz < 9999lu * 1024lu) // kilobytes
    {
        unsigned long div = 1024lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%4ld K", res + (_sz - res * div) / (div/2));
    }
    else if(_sz < 9999lu * 1048576lu) // megabytes
    {
        unsigned long div = 1048576lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%4ld M", res + (_sz - res * div) / (div/2));
    }
    else if(_sz < 9999lu * 1073741824lu) // gigabytes
    {
        unsigned long div = 1073741824lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%4ld G", res + (_sz - res * div) / (div/2));
    }
    else if(_sz < 9999lu * 1099511627776lu) // terabytes
    {
        unsigned long div = 1099511627776lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%4ld T", res + (_sz - res * div) / (div/2));
    }
    else if(_sz < 9999lu * 1125899906842624lu) // petabytes
    {
        unsigned long div = 1125899906842624lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%4ld P", res + (_sz - res * div) / (div/2));
    }
    else memset(buf, 0, 32);
    
    for(int i = 0; i < 6; ++i) _out[i] = buf[i];
}

static void FormHumanReadableSizeReprentationForDirEnt6(const DirectoryEntryInformation *_dirent, UniChar _out[6])
{
    if( _dirent->isdir() )
    {
        if( _dirent->size != DIRENTINFO_INVALIDSIZE)
        {
            FormHumanReadableSizeRepresentation6(_dirent->size, _out); // this code will be used some day when F3 will be implemented
        }
        else
        {
            char buf[32];
            memset(buf, 0, sizeof(buf));
            
            if( !_dirent->isdotdot()) strcpy(buf, "Folder");
            else                      strcpy(buf, "    Up");
            
            for(int i = 0; i < 6; ++i) _out[i] = buf[i];
        }
    }
    else
    {
        FormHumanReadableSizeRepresentation6(_dirent->size, _out);
    }
}

static void ComposeFooterFileNameForEntry(const DirectoryEntryInformation &_dirent, UniChar _buff[256], size_t &_sz)
{   // output is a direct filename or symlink path in ->filename form
    if(!_dirent.issymlink())
    {
        InterpretUTF8BufferAsUniChar( _dirent.name(), _dirent.namelen, _buff, &_sz, 0xFFFD);
    }
    else
    {
        if(_dirent.symlink != 0)
        {
            _buff[0]='-';
            _buff[1]='>';
            InterpretUTF8BufferAsUniChar( (unsigned char*)_dirent.symlink, strlen(_dirent.symlink), _buff+2, &_sz, 0xFFFD);
            _sz += 2;
        }
        else
        {
            _sz = 0; // fallback case
        }
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
// class IconCache
///////////////////////////////////////////////////////////////////////////////////////////////////
class ModernPanelViewPresentation::IconCache
{
public:
    IconCache(ModernPanelViewPresentation *_presentation)
    :   m_ParentDir(nil),
        m_Presentation(_presentation),
        m_IconsSize(0),
        m_LoadIconsRunning(false),
        m_LoadIconShouldStop(nullptr)
    {
        pthread_mutex_init(&m_Lock, NULL);
        m_LoadIconsGroup = dispatch_group_create();
        
        if (m_RefCount > 0)
            ++m_RefCount;
        else
        {
            assert(m_RefCount == 0);
            m_RefCount = 1;
            
            // Load predefined directory icon.
            NSImage *image = [NSImage imageNamed:NSImageNameFolder];
            m_GenericFolderIcon = [image bestRepresentationForRect:NSMakeRect(0, 0, 16, 16) context:nil
                                                            hints:nil];
            
            // Load predefined generic document file icon.
            image = [[NSWorkspace sharedWorkspace]
                     iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
            m_GenericFileIcon = [image bestRepresentationForRect:NSMakeRect(0, 0, 16, 16) context:nil
                                                           hints:nil];
        }
    }
    
    ~IconCache()
    {
        ClearIcons();
        
        dispatch_group_wait(m_LoadIconsGroup, 5*USEC_PER_SEC);
        
        pthread_mutex_destroy(&m_Lock);
        
        dispatch_release(m_LoadIconsGroup);
        assert(m_RefCount > 0);
        if (--m_RefCount == 0)
        {
            m_GenericFileIcon = nil;
            m_GenericFolderIcon = nil;
        }
    }
    
    inline NSImageRep *CreateIcon(const DirectoryEntryInformation &_item, int _item_index, PanelData *_data)
    {
        // If item has no associated icon, then create entry for the icon and schedule the loading
        // process.
        assert(&_data->EntryAtRawPosition(_item_index) == &_item);
        unsigned short index = (unsigned short)(m_UniqueIcons.size() + 1);
        _data->CustomIconSet(_item_index, index);
        
        UniqueIcon icon;
        if (_item.isdir())
            icon.image = m_GenericFolderIcon;
        else if (!_item.hasextension())
            icon.image = m_GenericFileIcon;
        else
        {
            NSString *ext = [NSString stringWithUTF8String:_item.extensionc()];
            NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:ext];
            icon.image = [image bestRepresentationForRect:NSMakeRect(0, 0, 16, 16) context:nil hints:nil];
        }
        
        icon.item_path = [(__bridge NSString *)_item.cf_name copy];
        icon.try_create_thumbnail = (_item.size < 256*1024*1024); // size less than 256 MB.
        m_UniqueIcons.push_back(icon);
        ++m_IconsSize;
        return icon.image;
    }
    
    inline NSImageRep *GetIcon(const DirectoryEntryInformation &_item)
    {
        assert(_item.cicon);
        unsigned short index = _item.cicon - 1;
        assert(index < m_UniqueIcons.size());
        return m_UniqueIcons[index].image;
        
    }
    
    void RunLoadThread(PanelData *_data)
    {
        pthread_mutex_lock(&m_Lock);

        if (m_LoadIconsRunning)
        {
            pthread_mutex_unlock(&m_Lock);
            return;
        }
        
        // Start loading thread.
        
        // Find the first not loaded icon.
        __block int count = 0;
        UniqueIconsT::iterator start = m_UniqueIcons.begin();
        for (auto end = m_UniqueIcons.end(); start != end; ++start, ++count)
            if (start->item_path) break;
        
        if (!m_ParentDir)
        {
            char buff[1024] = {0};
            _data->GetDirectoryPathWithTrailingSlash(buff);
            m_ParentDir = [NSString stringWithUTF8String:buff];
        }
        
        NSString *parent_dir = m_ParentDir;
        
        __block volatile bool *should_stop = new bool(false);
        m_LoadIconShouldStop = should_stop;
        m_LoadIconsRunning = true;
        
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        dispatch_block_t block =
        ^{
            uint64_t last_draw_time = GetTimeInNanoseconds();
            UniqueIconsT::iterator i = start;
            
            UniqueIcon *icon = nullptr;
            NSString *item_path;
            bool try_create_thumbnail;
            NSImage *image;
            
            for (;;)
            {
                // While lock is aqcuired, check that block needs to stop and get the next icon.
                pthread_mutex_lock(&m_Lock);
                
                if (*should_stop)
                {
                    pthread_mutex_unlock(&m_Lock);
                    break;
                }
                
                if (icon)
                {
                    // Apply the image we acquired during last iteration.
                    icon->image = [image bestRepresentationForRect:NSMakeRect(0, 0, 16, 16) context:nil hints:nil];
                    icon->item_path = nil;
                }
                
                // Check if icons are exhausted.
                assert(count <= m_IconsSize);
                if (count == m_IconsSize)
                {
                    dispatch_async(dispatch_get_main_queue(),
                                   ^{ m_Presentation->SetViewNeedsDisplay(); });
                    m_LoadIconsRunning = false;
                    pthread_mutex_unlock(&m_Lock);
                    break;
                }
                
                ++count;
                icon = &*i++;
                assert(icon->item_path);
                item_path = icon->item_path;
                try_create_thumbnail = icon->try_create_thumbnail;
                
                pthread_mutex_unlock(&m_Lock);
                
                
                item_path = [parent_dir stringByAppendingString:item_path];
                
                CGImageRef thumbnail = NULL;
                if (try_create_thumbnail)
                {
                    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:item_path];
                    
                    void *keys[] = {(void*)kQLThumbnailOptionIconModeKey};
                    void *values[] = {(void*)kCFBooleanTrue};
                    CFDictionaryRef dict = CFDictionaryCreate(CFAllocatorGetDefault(),
                                                              (const void**)keys,
                                                              (const void**)values,
                                                              1, NULL, NULL);
                    thumbnail = QLThumbnailImageCreate(CFAllocatorGetDefault(), url,
                                                       NSMakeSize(16, 16), dict);
                    CFRelease(dict);
                }
                
                if (thumbnail != NULL)
                {
                    image = [[NSImage alloc] initWithCGImage:thumbnail size:NSMakeSize(16, 16)];
                    CGImageRelease(thumbnail);
                }
                else
                {
                    image = [[NSWorkspace sharedWorkspace] iconForFile:item_path];
                }
                
                if (*should_stop) break;
                
                uint64_t curtime = GetTimeInNanoseconds();
                if (curtime - last_draw_time > 500*NSEC_PER_MSEC)
                {
                    dispatch_async(dispatch_get_main_queue(),
                                   ^{ m_Presentation->SetViewNeedsDisplay(); });
                    last_draw_time = curtime;
                }
            }
            
            delete should_stop;
        };
        
        dispatch_group_async(m_LoadIconsGroup, queue, block);

        pthread_mutex_unlock(&m_Lock);
    }

    void OnDirectoryChanged(PanelData *_data)
    {
        ClearIcons();
        
        m_ParentDir = nil;
    }
    
private:
    void ClearIcons()
    {
        if (m_LoadIconsRunning)
        {
            pthread_mutex_lock(&m_Lock);
            if (m_LoadIconsRunning)
            {
                *m_LoadIconShouldStop = true;
                m_LoadIconsRunning = false;
            }
            pthread_mutex_unlock(&m_Lock);
        }

        m_IconsSize = 0;
        m_UniqueIcons.clear();
    }
    
    struct UniqueIcon
    {
        NSImageRep *image;
        NSString *item_path;
        bool try_create_thumbnail;
    };
    typedef std::deque<UniqueIcon> UniqueIconsT;
    
    UniqueIconsT m_UniqueIcons;
    volatile int m_IconsSize;
    NSString *m_ParentDir;
    
    ModernPanelViewPresentation *m_Presentation;
    
    dispatch_group_t m_LoadIconsGroup;
    volatile bool m_LoadIconsRunning;
    volatile bool *m_LoadIconShouldStop;
    pthread_mutex_t m_Lock;
                                
    static NSImageRep *m_GenericFileIcon;
    static NSImageRep *m_GenericFolderIcon;
    static int m_RefCount;
};

int ModernPanelViewPresentation::IconCache::m_RefCount = 0;
NSImageRep *ModernPanelViewPresentation::IconCache::m_GenericFileIcon = nil;
NSImageRep *ModernPanelViewPresentation::IconCache::m_GenericFolderIcon = nil;

///////////////////////////////////////////////////////////////////////////////////////////////////
// class ModernPanelViewPresentation
///////////////////////////////////////////////////////////////////////////////////////////////////

// Item name display insets inside the item line.
// Order: left, top, right, bottom.
const int g_TextInsetsInLine[4] = {7, 0, 5, 1};
// Width of the divider between views.
const int g_DividerWidth = 3;

ModernPanelViewPresentation::ModernPanelViewPresentation()
:   m_FirstDraw(false)
{
    m_IconCache = new IconCache(this);
    
    m_Size.width = m_Size.height = 0;
    
    m_Font = [NSFont fontWithName:@"Lucida Grande" size:13];
    
    // Height of a single file line. Constant for now, needs to be calculated from the font.
    m_LineHeight = 18;
    
    
    // Init active header and footer gradient.
    {
        CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
        const CGFloat outer_color[3] = { 200/255.0, 230/255.0, 245/255.0 };
        const CGFloat inner_color[3] = { 130/255.0, 196/255.0, 240/255.0 };
        CGFloat components[] =
        {
            outer_color[0], outer_color[1], outer_color[2], 1.0,
            inner_color[0], inner_color[1], inner_color[2], 1.0,
            inner_color[0], inner_color[1], inner_color[2], 1.0,
            outer_color[0], outer_color[1], outer_color[2], 1.0
        };
        CGFloat locations[] = {0.0, 0.45, 0.55, 1.0};
        m_ActiveHeaderGradient = CGGradientCreateWithColorComponents(color_space, components, locations, 4);
        CGColorSpaceRelease(color_space);
    }
    
    // Init inactive header and footer gradient.
    {
        CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
        const CGFloat upper_color[3] = { 220/255.0, 220/255.0, 220/255.0 };
        const CGFloat bottom_color[3] = { 200/255.0, 200/255.0, 200/255.0 };
        CGFloat components[] =
        {
            upper_color[0], upper_color[1], upper_color[2], 1.0,
            upper_color[0], upper_color[1], upper_color[2], 1.0,
            bottom_color[0], bottom_color[1], bottom_color[2], 1.0,
            bottom_color[0], bottom_color[1], bottom_color[2], 1.0
        };
        CGFloat locations[] = {0.0, 0.45, 0.7, 1.0};
        m_InactiveHeaderGradient = CGGradientCreateWithColorComponents(color_space, components, locations, 4);
        CGColorSpaceRelease(color_space);
    }
    
    // Active header and footer text shadow.
    {
        m_ActiveHeaderTextShadow = [[NSShadow alloc] init];
        m_ActiveHeaderTextShadow.shadowBlurRadius = 1;
        m_ActiveHeaderTextShadow.shadowColor = [NSColor colorWithDeviceRed:0.83 green:0.93 blue:1 alpha:1];
        m_ActiveHeaderTextShadow.shadowOffset = NSMakeSize(0, -1);
    }
    
    // Inactive header and footer text shadow.
    {
        m_InactiveHeaderTextShadow = [[NSShadow alloc] init];
        m_InactiveHeaderTextShadow.shadowBlurRadius = 1;

        m_InactiveHeaderTextShadow.shadowColor = [NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:0.9];
        m_InactiveHeaderTextShadow.shadowOffset = NSMakeSize(0, -1);
    }
}

ModernPanelViewPresentation::~ModernPanelViewPresentation()
{
    CGGradientRelease(m_ActiveHeaderGradient);
    CGGradientRelease(m_InactiveHeaderGradient);
    
    assert(m_IconCache);
    delete m_IconCache;
    
    m_State->Data->CustomIconClearAll();
}

void ModernPanelViewPresentation::Draw(NSRect _dirty_rect)
{
    if (!m_State || !m_State->Data) return;
    assert(m_State->CursorPos < (int)m_State->Data->SortedDirectoryEntries().size());
    assert(m_State->ItemsDisplayOffset >= 0);
    
    auto &sorted_entries = m_State->Data->SortedDirectoryEntries();
    auto &entries = m_State->Data->DirectoryEntries();
    const int items_per_column = GetMaxItemsPerColumn();
    const int max_items = (int)sorted_entries.size();
    const int columns_count = GetNumberOfItemColumns();
    
    
    ///////////////////////////////////////////////////////////////////////////////
    // Prepare icons for
    bool created_icons = false;
    int count = 0, total_count = items_per_column*columns_count;
    int i = m_State->ItemsDisplayOffset;
    for(; count < total_count && i < max_items; ++count, ++i)
    {
        int raw_index = sorted_entries[i];
        const DirectoryEntryInformation &entry = entries[raw_index];
        if (entry.cicon == 0)
        {
            created_icons = true;
            m_IconCache->CreateIcon(entry, raw_index, m_State->Data);
        }
    }
    
    if (created_icons)
    {
        m_IconCache->RunLoadThread(m_State->Data);

        // On the first draw of a directory: do not draw anything, wait for some icons to load to avoid annoying flickering of the icons.
        if (m_FirstDraw)
        {
            m_FirstDraw = false;
            
            // Schedule redraw.
            dispatch_time_t pop_time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50*NSEC_PER_MSEC));
            dispatch_after(pop_time, dispatch_get_main_queue(), ^(void){
                SetViewNeedsDisplay();
            });
            
            return;
        }
    }
    
    ///////////////////////////////////////////////////////////////////////////////
    // Clear view background.
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, NSRectToCGRect(_dirty_rect));
    
    ///////////////////////////////////////////////////////////////////////////////
    // Divider.
    CGColorRef divider_stroke_color = CGColorCreateGenericRGB(101/255.0, 101/255.0, 101/255.0, 1.0);
    CGColorRef divider_fill_color = CGColorCreateGenericRGB(174/255.0, 174/255.0, 174/255.0, 1.0);
    
    CGContextSetStrokeColorWithColor(context, divider_stroke_color);
    if (m_IsLeft)
    {
        float x = m_ItemsArea.origin.x + m_ItemsArea.size.width;
        NSPoint view_divider[2] = {
            NSMakePoint(x + 0.5, 0), NSMakePoint(x + 0.5, m_Size.height)
        };
        CGContextStrokeLineSegments(context, view_divider, 2);
        
        
        CGContextSetFillColorWithColor(context, divider_fill_color);
        CGContextFillRect(context, NSMakeRect(x + 1, 0, g_DividerWidth - 1, m_Size.height));
    }
    else
    {
        NSPoint view_divider[2] = {
            NSMakePoint(g_DividerWidth - 0.5, 0), NSMakePoint(g_DividerWidth - 0.5, m_Size.height)
        };
        CGContextStrokeLineSegments(context, view_divider, 2);
        
        
        CGContextSetFillColorWithColor(context, divider_fill_color);
        CGContextFillRect(context, NSMakeRect(0, 0, g_DividerWidth - 1, m_Size.height));
    }
    
    CGColorRelease(divider_fill_color);
    CGColorRelease(divider_stroke_color);
    
    // If current panel is on the right, then translate all rendering by the divider's width.
    if (!m_IsLeft) CGContextTranslateCTM(context, g_DividerWidth, 0);
    
    
    ///////////////////////////////////////////////////////////////////////////////
    // Header and footer.
    CGColorRef header_stroke_color = CGColorCreateGenericRGB(102/255.0, 102/255.0, 102/255.0, 1.0);
    int header_height = m_ItemsArea.origin.y;
    
    NSShadow *header_text_shadow = m_ActiveHeaderTextShadow;
    if (!m_State->Active) header_text_shadow = m_InactiveHeaderTextShadow;
    
    CGGradientRef header_gradient = m_ActiveHeaderGradient;
    if (!m_State->Active) header_gradient = m_InactiveHeaderGradient;
    
    // Header gradient.
    CGContextSaveGState(context);
    NSRect header_rect = NSMakeRect(0, 0, m_ItemsArea.size.width, header_height - 1);
    CGContextAddRect(context, header_rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, header_gradient, header_rect.origin,
                                NSMakePoint(header_rect.origin.x,
                                            header_rect.origin.y + header_rect.size.height), 0);
    CGContextRestoreGState(context);
    
    // Header line separator.
    CGContextSetStrokeColorWithColor(context, header_stroke_color);
    NSPoint header_points[2] = {
        NSMakePoint(0, header_height - 0.5), NSMakePoint(m_ItemsArea.size.width, header_height - 0.5)
    };
    CGContextStrokeLineSegments(context, header_points, 2);
    
    // Panel path.
    char panelpath[__DARWIN_MAXPATHLEN] = {0};
    m_State->Data->GetDirectoryPathWithTrailingSlash(panelpath);
    NSString *header_string = [NSString stringWithUTF8String:panelpath];
    
    int delta = (header_height - m_LineHeight)/2;
    NSRect rect = NSMakeRect(20, delta, m_ItemsArea.size.width - 40, m_LineHeight);
    
    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
    
    NSMutableParagraphStyle *header_text_pstyle = [[NSMutableParagraphStyle alloc] init];
    header_text_pstyle.alignment = NSCenterTextAlignment;
    header_text_pstyle.lineBreakMode = NSLineBreakByTruncatingHead;
    
    NSDictionary *header_text_attr =@{NSFontAttributeName: m_Font,
                                      NSParagraphStyleAttributeName: header_text_pstyle,
                                      NSShadowAttributeName: header_text_shadow};
    
    [header_string drawWithRect:rect options:options attributes:header_text_attr];
    
    
    // Footer
    const int footer_y = m_ItemsArea.origin.y + m_ItemsArea.size.height;
    
    // Footer gradient.
    CGContextSaveGState(context);
    NSRect footer_rect = NSMakeRect(0, footer_y + 1, m_ItemsArea.size.width, header_height - 1);
    CGContextAddRect(context, footer_rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, header_gradient, footer_rect.origin,
                                NSMakePoint(footer_rect.origin.x,
                                            footer_rect.origin.y + footer_rect.size.height), 0);
    CGContextRestoreGState(context);
    
    // Footer line separator.
    CGContextSetStrokeColorWithColor(context, header_stroke_color);
    NSPoint footer_points[2] = {
        NSMakePoint(0, footer_y + 0.5), NSMakePoint(m_ItemsArea.size.width, footer_y + 0.5)
    };
    CGContextStrokeLineSegments(context, footer_points, 2);
    
    // Footer string.
    // If any number of items are selected, then draw selection stats.
    // Otherwise, draw stats of cursor item.
    if(m_State->Data->GetSelectedItemsCount() != 0)
    {
        UniChar selectionbuf[512];
        size_t sz;
        FormHumanReadableBytesAndFiles(m_State->Data->GetSelectedItemsSizeBytes(),
                                       m_State->Data->GetSelectedItemsCount(), selectionbuf, sz);
        
        NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
        const int delta = (header_height - m_LineHeight)/2;
        const int offset = 10;
        
        NSMutableParagraphStyle *footer_text_pstyle = [[NSMutableParagraphStyle alloc] init];
        footer_text_pstyle.alignment = NSCenterTextAlignment;
        footer_text_pstyle.lineBreakMode = NSLineBreakByTruncatingHead;
        
        NSDictionary *footer_text_attr = @{NSFontAttributeName: m_Font,
                                           NSParagraphStyleAttributeName: footer_text_pstyle,
                                           NSShadowAttributeName: header_text_shadow};
        
        NSString *sel_str = [NSString stringWithCharacters:selectionbuf length:sz];
        [sel_str drawWithRect:NSMakeRect(offset, footer_y + delta,
                                         m_ItemsArea.size.width - 2*offset, m_LineHeight)
                      options:options attributes:footer_text_attr];
    }
    else if(m_State->CursorPos >= 0)
    {
        UniChar buff[256];
        UniChar time_info[14], size_info[6];
        size_t buf_size = 0;
        const DirectoryEntryInformation *current_entry = &entries[sorted_entries[m_State->CursorPos]];
        
        FormHumanReadableTimeRepresentation14(current_entry->mtime, time_info);
        FormHumanReadableSizeReprentationForDirEnt6(current_entry, size_info);
        
        NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
        const int delta = (header_height - m_LineHeight)/2;
        const int offset = 10;
        int time_width = 110;
        int size_width = 90;
        
        NSMutableParagraphStyle *footer_text_pstyle;
        NSDictionary *footer_text_attr;
        
        if (m_State->ViewType != PanelViewType::ViewFull)
        {
            footer_text_pstyle = [[NSMutableParagraphStyle alloc] init];
            footer_text_pstyle.alignment = NSRightTextAlignment;
            footer_text_pstyle.lineBreakMode = NSLineBreakByClipping;
            
            footer_text_attr = @{NSFontAttributeName: m_Font,
                                 NSParagraphStyleAttributeName:footer_text_pstyle,
                                 NSShadowAttributeName: header_text_shadow};
            
            NSString *time_str = [NSString stringWithCharacters:time_info length:14];
            [time_str drawWithRect:NSMakeRect(m_ItemsArea.size.width - offset - time_width,
                                              footer_y + delta,
                                              time_width, m_LineHeight)
                           options:options attributes:footer_text_attr];
            
            NSString *size_str = [NSString stringWithCharacters:size_info length:6];
            [size_str drawWithRect:NSMakeRect(m_ItemsArea.size.width - offset - time_width - size_width,
                                              footer_y + delta,
                                              size_width, m_LineHeight)
                           options:options attributes:footer_text_attr];
        }
        
        footer_text_pstyle = [[NSMutableParagraphStyle alloc] init];
        footer_text_pstyle.alignment = NSLeftTextAlignment;
        footer_text_pstyle.lineBreakMode = NSLineBreakByTruncatingHead;
        
        footer_text_attr = @{NSFontAttributeName: m_Font,
                             NSParagraphStyleAttributeName: footer_text_pstyle,
                             NSShadowAttributeName: header_text_shadow};
        
        int name_width = m_ItemsArea.size.width - 2*offset;
        if (m_State->ViewType != PanelViewType::ViewFull)
            name_width -= time_width + size_width;
        ComposeFooterFileNameForEntry(*current_entry, buff, buf_size);
        NSString *name_str = [NSString stringWithCharacters:buff length:buf_size];
        [name_str drawWithRect:NSMakeRect(offset, footer_y + delta, name_width, m_LineHeight) options:options attributes:footer_text_attr];
    }
    
    CGColorRelease(header_stroke_color);
    
    
    ///////////////////////////////////////////////////////////////////////////////
    // Draw items in columns.
    NSMutableParagraphStyle *item_text_pstyle = [[NSMutableParagraphStyle alloc] init];
    item_text_pstyle.alignment = NSLeftTextAlignment;
    item_text_pstyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    
    NSDictionary *item_text_attr = @{NSFontAttributeName: m_Font,
                                     NSParagraphStyleAttributeName: item_text_pstyle};
    
    NSDictionary *active_selected_item_text_attr =
    @{
      NSFontAttributeName: m_Font,
      NSForegroundColorAttributeName: [NSColor whiteColor],
      NSParagraphStyleAttributeName: item_text_pstyle
      };
    
    CGColorRef active_selected_item_back = CGColorCreateGenericRGB(43/255.0, 116/255.0, 211/255.0, 1.0);
    CGColorRef inactive_selected_item_back = CGColorCreateGenericRGB(212/255.0, 212/255.0, 212/255.0, 1.0);
    CGColorRef active_cursor_item_back = CGColorCreateGenericRGB(130/255.0, 196/255.0, 240/255.0, 1.0);
    CGColorRef column_divider_color = CGColorCreateGenericRGB(224/255.0, 224/255.0, 224/255.0, 1.0);
    CGColorRef cursor_frame_color = CGColorCreateGenericRGB(0, 0, 0, 1);
    CGColorRef item_back = CGColorCreateGenericRGB(240/255.0, 245/255.0, 250/255.0, 1);
    
    const int icon_size = 16;
    const int start_y = m_ItemsArea.origin.y;
    
    // The widths of columns that are displayed for wide and full views.
    const int size_column_width = 65;
    const int date_column_width = 70;
    const int time_column_width = 50;
    
    for (int column = 0; column < columns_count; ++column)
    {
        // Draw column.
        int column_width = int(m_ItemsArea.size.width - (columns_count - 1))/columns_count;
        // Calculate index of the first item in current column.
        int i = m_State->ItemsDisplayOffset + column*items_per_column;
        // X position of items.
        int start_x = column*(column_width + 1);
        
        if (column == columns_count - 1)
            column_width += int(m_ItemsArea.size.width - (columns_count - 1))%columns_count;
        
        // Draw column divider.
        if (column < columns_count - 1)
        {
            NSPoint points[2] = {
                NSMakePoint(start_x + 0.5 + column_width, start_y),
                NSMakePoint(start_x + 0.5 + column_width, start_y + m_ItemsArea.size.height)
            };
            CGContextSetStrokeColorWithColor(context, column_divider_color);
            CGContextSetLineWidth(context, 1);
            CGContextStrokeLineSegments(context, points, 2);
        }
        
        int count = 0;
        for (; count < items_per_column && i < max_items; ++count, ++i)
        {
            auto raw_index = sorted_entries[i];
            auto &item = entries[raw_index];
            NSString *item_name = (__bridge NSString *)item.cf_name;
            
            NSRect rect = NSMakeRect(start_x + icon_size + 2*g_TextInsetsInLine[0],
                                     start_y + count*m_LineHeight + g_TextInsetsInLine[1],
                                     column_width - icon_size - 2*g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                     m_LineHeight - g_TextInsetsInLine[1] - g_TextInsetsInLine[3]);
            
            NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
            
            NSDictionary *cur_item_text_attr = item_text_attr;
            if (m_State->Active && item.cf_isselected())
                cur_item_text_attr = active_selected_item_text_attr;
            
            // Draw background.
            if (item.cf_isselected())
            {
                // Draw selected item.
                if (m_State->Active)
                {
                    int offset = 1;
                    if (m_State->CursorPos == i && m_State->Active) offset = 2;
                    CGContextSetFillColorWithColor(context, active_selected_item_back);
                    CGContextFillRect(context, NSMakeRect(start_x + offset,
                                                          start_y + count*m_LineHeight + offset,
                                                          column_width - 2*offset,
                                                          m_LineHeight - 2*offset + 1));
                }
                else
                {
                    CGContextSetFillColorWithColor(context, inactive_selected_item_back);
                    CGContextFillRect(context, NSMakeRect(start_x + 1,
                                                          start_y + count*m_LineHeight + 1,
                                                          column_width - 2, m_LineHeight - 1));
                }
            }
            else if ((count + column) % 2 == 1)
            {
                CGContextSetFillColorWithColor(context, item_back);
                
                CGContextFillRect(context, NSMakeRect(start_x + 1, start_y + count*m_LineHeight + 1,
                                                      column_width - 2, m_LineHeight - 1));
            }
            
            // Draw cursor.
            if (m_State->CursorPos == i && m_State->Active)
            {
                // Draw as cursor item (only if panel is active).
                CGContextSaveGState(context);
                CGFloat dashes[2] = { 2, 4 };
                CGContextSetLineDash(context, 0, dashes, 2);
                CGContextSetStrokeColorWithColor(context, cursor_frame_color);
                CGContextStrokeRect(context, NSMakeRect(start_x + 1.5,
                                                        start_y + count*m_LineHeight + 1.5,
                                                        column_width - 3, m_LineHeight - 2));
                CGContextRestoreGState(context);
            }
            
            // Draw stats columns for specific views.
            int spec_col_x = m_ItemsArea.size.width;
            if (m_State->ViewType == PanelViewType::ViewFull)
            {
                UniChar date_info[8], time_info[5];
                FormHumanReadableDateRepresentation8(item.mtime, date_info);
                FormHumanReadableTimeRepresentation5(item.mtime, time_info);
                
                NSRect time_rect = NSMakeRect(spec_col_x - time_column_width + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              time_column_width - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);
                
                NSString *time_str = [NSString stringWithCharacters:time_info length:5];
                [time_str drawWithRect:time_rect options:options attributes:cur_item_text_attr];
                
                rect.size.width -= time_column_width;
                spec_col_x -= time_column_width;
                
                NSRect date_rect = NSMakeRect(spec_col_x - date_column_width + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              date_column_width - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);
                NSString *date_str = [NSString stringWithCharacters:date_info length:8];
                [date_str drawWithRect:date_rect options:options attributes:cur_item_text_attr];
                
                rect.size.width -= date_column_width;
                spec_col_x -= date_column_width;
            }
            if(m_State->ViewType == PanelViewType::ViewWide
               || m_State->ViewType == PanelViewType::ViewFull)
            {
                // draw the entry size on the right
                NSRect size_rect = NSMakeRect(spec_col_x - size_column_width + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              size_column_width - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);
                
                NSMutableParagraphStyle *pstyle = [[NSMutableParagraphStyle alloc] init];
                pstyle.alignment = NSRightTextAlignment;
                pstyle.lineBreakMode = NSLineBreakByClipping;
                
                NSColor *color = m_State->Active && item.cf_isselected()
                ? [NSColor whiteColor] : [NSColor blackColor];
                NSDictionary *attr = @{NSFontAttributeName: m_Font,
                                       NSForegroundColorAttributeName: color,
                                       NSParagraphStyleAttributeName: pstyle};
                
                UniChar size_info[6];
                FormHumanReadableSizeReprentationForDirEnt6(&item, size_info);
                NSString *size_str = [NSString stringWithCharacters:size_info length:6];
                [size_str drawWithRect:size_rect options:options attributes:attr];
                
                rect.size.width -= size_column_width;
            }
            
            // Draw item text.
            [item_name drawWithRect:rect options:options attributes:cur_item_text_attr];
            

            // Draw icon
            NSImageRep *image_rep = m_IconCache->GetIcon(item);
            NSRect icon_rect = NSMakeRect(start_x + g_TextInsetsInLine[0],
                                     start_y + count*m_LineHeight + m_LineHeight - icon_size - 1,
                                     icon_size, icon_size);
            [image_rep drawInRect:icon_rect fromRect:NSZeroRect operation:NSCompositeSourceOver
                         fraction:1.0 respectFlipped:YES hints:nil];
        }
    }
    
    // Draw column dividers for specific views.
    if (m_State->ViewType == PanelViewType::ViewWide)
    {
        int x = m_ItemsArea.size.width - size_column_width;
        NSPoint points[2] = {
            NSMakePoint(x + 0.5, start_y),
            NSMakePoint(x + 0.5, start_y + m_ItemsArea.size.height)
        };
        CGContextSetStrokeColorWithColor(context, column_divider_color);
        CGContextSetLineWidth(context, 1);
        CGContextStrokeLineSegments(context, points, 2);
    }
    else if (m_State->ViewType == PanelViewType::ViewFull)
    {
        int x_pos[3];
        x_pos[0] = m_ItemsArea.size.width - time_column_width;
        x_pos[1] = x_pos[0] - date_column_width;
        x_pos[2] = x_pos[1] - size_column_width;
        for (int i = 0; i < 3; ++i)
        {
            int x = x_pos[i];
            NSPoint points[2] = {
                NSMakePoint(x + 0.5, start_y),
                NSMakePoint(x + 0.5, start_y + m_ItemsArea.size.height)
            };
            CGContextSetStrokeColorWithColor(context, column_divider_color);
            CGContextSetLineWidth(context, 1);
            CGContextStrokeLineSegments(context, points, 2);
        }
    }
    
    CGColorRelease(active_selected_item_back);
    CGColorRelease(inactive_selected_item_back);
    CGColorRelease(active_cursor_item_back);
    CGColorRelease(column_divider_color);
    CGColorRelease(cursor_frame_color);
    CGColorRelease(item_back);
}

void ModernPanelViewPresentation::OnFrameChanged(NSRect _frame)
{
    m_Size = _frame.size;
    
    m_IsLeft = _frame.origin.x < 50;

    // Header and footer have the same height.
    const int header_height = m_LineHeight + 1;
    
    m_ItemsArea.origin.x = 0;
    m_ItemsArea.origin.y = header_height;
    m_ItemsArea.size.height = m_Size.height - 2*header_height;
    m_ItemsArea.size.width = m_Size.width - g_DividerWidth;
    if (!m_IsLeft) m_ItemsArea.origin.x += g_DividerWidth;
    
    m_ItemsPerColumn = int(m_ItemsArea.size.height/m_LineHeight);
    
    EnsureCursorIsVisible();
}

NSRect ModernPanelViewPresentation::GetItemColumnsRect()
{
    return m_ItemsArea;
}

int ModernPanelViewPresentation::GetItemIndexByPointInView(CGPoint _point)
{
    const int columns = GetNumberOfItemColumns();
    const int entries_in_column = GetMaxItemsPerColumn();
    
    NSRect items_rect = GetItemColumnsRect();
    
    // Check if click is in files' view area, including horizontal bottom line.
    if (!NSPointInRect(_point, items_rect)) return -1;
    
    // Calculate the number of visible files.
    auto &sorted_entries = m_State->Data->SortedDirectoryEntries();
    const int max_files_to_show = entries_in_column * columns;
    int visible_files = (int)sorted_entries.size() - m_State->ItemsDisplayOffset;
    if (visible_files > max_files_to_show) visible_files = max_files_to_show;
    
    // Calculate width of column.
    const int column_width = items_rect.size.width / columns;
    
    // Calculate cursor pos.
    int column = int(_point.x/column_width);
    int row = int((_point.y - items_rect.origin.y)/m_LineHeight);
    if (row >= entries_in_column) row = entries_in_column - 1;
    int file_number =  row + column*entries_in_column;
    if (file_number >= visible_files) file_number = visible_files - 1;
    
    return m_State->ItemsDisplayOffset + file_number;
}

int ModernPanelViewPresentation::GetNumberOfItemColumns()
{
    switch(m_State->ViewType)
    {
        case PanelViewType::ViewShort: return 3;
        case PanelViewType::ViewMedium: return 2;
        case PanelViewType::ViewWide: return 1;
        case PanelViewType::ViewFull: return 1;
    }
    assert(0);
    return 0;
}

int ModernPanelViewPresentation::GetMaxItemsPerColumn()
{
    return m_ItemsPerColumn;
}

void ModernPanelViewPresentation::UpdatePanelFrames(PanelView *_left, PanelView *_right, NSSize _size)
{
}

void ModernPanelViewPresentation::OnDirectoryChanged()
{
    m_IconCache->OnDirectoryChanged(m_State->Data);
    m_FirstDraw = true;
}
