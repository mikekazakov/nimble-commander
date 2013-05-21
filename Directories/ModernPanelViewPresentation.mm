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

#import <string>


static void FormHumanReadableBytesAndFiles(unsigned long _sz, int _total_files, UniChar _out[128], size_t &_symbs)
{
    // TODO: localization support
    char buf[128];
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
    IconCache()
    :   m_ParentDir(nil),
        m_LastFlushTime(0)
    {
        if (m_TypeIcons)
        {
            assert(m_TypeIconsRefCount > 0);
            ++m_TypeIconsRefCount;
        }
        else
        {
            assert(m_TypeIconsRefCount == 0);
            m_TypeIcons = new TypeIconsT;
            m_TypeIconsRefCount = 1;
            m_TypeIcons->reserve(32);
            
            // Load predefined directory icon.
            assert(DirectoryIconIndex == 1);
            m_TypeIcons->push_back(TypeIcon());
            TypeIcon &dir_icon = m_TypeIcons->back();
            NSImage *image = [NSImage imageNamed:NSImageNameFolder];
            dir_icon.image = [image bestRepresentationForRect:NSMakeRect(0, 0, 16, 16) context:nil
                                                        hints:nil];
            
            // Load predefined generic document file icon.
            assert(GenericIconIndex == 2);
            m_TypeIcons->push_back(TypeIcon());
            TypeIcon &generic_icon = m_TypeIcons->back();
            image = [[NSWorkspace sharedWorkspace]
                     iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
            generic_icon.image = [image bestRepresentationForRect:NSMakeRect(0, 0, 16, 16) context:nil
                                                            hints:nil];
        }
        
        m_UniqueIcons.reserve(8);
    }
    
    ~IconCache()
    {
        assert(m_TypeIconsRefCount > 0);
        if (--m_TypeIconsRefCount == 0)
        {
            delete m_TypeIcons;
            m_TypeIcons = nullptr;
        }
    }
    
    inline NSImageRep *GetIcon(PanelData &_data, const DirectoryEntryInformation &_item, int _item_index, uint64_t _curtime)
    {
        uint32_t curtime_sec = uint32_t(_curtime/1000000000ul);
        
        // If item has no associated icon, then get it.
        if (_item.cicon == 0)
        {
            bool is_unique = _item.isdir() && _item.hasextension() && strcasecmp(_item.extensionc(), "app") == 0;
            if (is_unique)
            {
                // Create unique icon entry. Load it later (see further below).
                assert(&_data.EntryAtRawPosition(_item_index) == &_item);
                unsigned short index = UniqueIconIndexFlag | (unsigned short)(m_UniqueIcons.size() + 1);
                _data.CustomIconSet(_item_index, index);
                m_UniqueIcons.push_back(UniqueIcon());
                UniqueIcon &back = m_UniqueIcons.back();
                back.image = nil;
                back.access_time = curtime_sec;
                back.loading = false;
            }
            else if (_item.isdir())
            {
                // Item is a directory, but not an app bundle.
                assert(&_data.EntryAtRawPosition(_item_index) == &_item);
                _data.CustomIconSet(_item_index, DirectoryIconIndex);
            }
            else if (!_item.hasextension())
            {
                // Item is a file with no extension.
                // Use generic icon.
                assert(&_data.EntryAtRawPosition(_item_index) == &_item);
                _data.CustomIconSet(_item_index, GenericIconIndex);
            }
            else
            {
                // Try to find existing icon entry for the item type.
                unsigned short size = m_TypeIcons->size();
                bool found = false;
                const char *ext = _item.extensionc();
                
                for (unsigned short i = 0; i < size; ++i)
                {
                    if (strcasecmp((*m_TypeIcons)[i].extension.c_str(), ext) == 0)
                    {
                        // Found!
                        assert(&_data.EntryAtRawPosition(_item_index) == &_item);
                        _data.CustomIconSet(_item_index, i + 1);
                        if ((*m_TypeIcons)[i].image) return (*m_TypeIcons)[i].image;
                        
                        // If image is nil, we need to reload it.
                        found = true;
                        break;
                    }
                }
                
                if (!found)
                {
                    // No icon is found for the item. Create new icon entry and load it (look further below).
                    assert(&_data.EntryAtRawPosition(_item_index) == &_item);
                    unsigned short index = size + 1;
                    assert(index < UniqueIconIndexFlag);
                    _data.CustomIconSet(_item_index, index);
                    m_TypeIcons->push_back(TypeIcon());
                    TypeIcon &back = m_TypeIcons->back();
                    back.extension = _item.extensionc();
                    back.image = nil;
                    back.loading = false;
                    back.access_time = curtime_sec;
                }
            }
        }
        
        // There is a valid index in item's cicon. Check if the icon is loaded and return it.
        
        // Branch for unique icons.
        if (_item.cicon & UniqueIconIndexFlag)
        {
            unsigned short index = (_item.cicon ^ UniqueIconIndexFlag) - 1;
            UniqueIcon &icon = m_UniqueIcons[index];
            icon.access_time = curtime_sec;
            
            if (icon.image) return icon.image;
           
            // Load icon.
            if (!icon.loading)
            {
                if (!m_ParentDir)
                {
                    char buff[1024] = {0};
                    _data.GetDirectoryPathWithTrailingSlash(buff);
                    m_ParentDir = [NSString stringWithUTF8String:buff];
                }
                NSString *path = [m_ParentDir stringByAppendingString:(__bridge NSString *)_item.cf_name];
                NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:path];
                icon.image = [image bestRepresentationForRect:NSMakeRect(0, 0, 16, 16) context:nil hints:nil];
            }
            
            return icon.image;
        }
        
        // Branch for type icons.
        unsigned short size = m_TypeIcons->size();
        assert(_item.cicon <= size);
        assert(_item.cicon > 0);
        
        TypeIcon &icon = (*m_TypeIcons)[_item.cicon - 1];
        icon.access_time = curtime_sec;
        
        if (icon.image) return icon.image;
        
        // Load icon.
        if (!icon.loading)
        {
            // Check that item's icon is not one of the predefined icons. They should be always
            // in memory.
            assert(_item.cicon != DirectoryIconIndex && _item.cicon != GenericIconIndex);
            // Sanity check.
            assert(strcasecmp(_item.extensionc(), icon.extension.c_str()) == 0);
            
        
            NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:[NSString stringWithUTF8String:_item.extensionc()]];
            
            icon.image = [image bestRepresentationForRect:NSMakeRect(0, 0, 16, 16) context:nil hints:nil];
        }

        return icon.image;
    }
    
    void OnDirectoryChanged(uint64_t _curtime)
    {
        m_ParentDir = nil;
        
        FlushIfNeeded(_curtime, true);
    }
    
    // If _delete_icons is true, flushing algorithm will force run, and instead of flushing icons
    // the whole icon entries will be deleted.
    void FlushIfNeeded(uint64_t _curtime, bool _delete_icons = false)
    {
        const uint32_t flush_delay_sec = 60;
        
        uint32_t curtime_sec = uint32_t(_curtime/1000000000ul);
        if (!_delete_icons && curtime_sec - m_LastFlushTime > flush_delay_sec) return;
        
        m_LastFlushTime = curtime_sec;
        
        const uint32_t obsolete_time_sec = 60;
        
        // Flush or delete unique icons.
        if (_delete_icons)
            m_UniqueIcons.clear();
        else
        {
            for (auto &icon : m_UniqueIcons)
            {
                if (curtime_sec - icon.access_time > obsolete_time_sec)
                    icon.image = nil;
            }
        }
        
        // Flush type icons.
        for (int i = PredefinedIndexesRange; i < m_TypeIcons->size(); ++i)
        {
            auto &icon = (*m_TypeIcons)[i];
            if (curtime_sec - icon.access_time > obsolete_time_sec)
                icon.image = nil;
        }
    }
    
private:
    enum
    {
        DirectoryIconIndex = 1,
        GenericIconIndex = 2,
        PredefinedIndexesRange = 2,
        
        UniqueIconIndexFlag = 0x8000u
    };
    struct TypeIcon
    {
        std::string extension;
        NSImageRep *image;
        uint32_t access_time;
        bool loading;
    };
    typedef std::vector<TypeIcon> TypeIconsT;
    struct UniqueIcon
    {
        NSImageRep *image;
        uint32_t access_time;
        bool loading;
    };
    typedef std::vector<UniqueIcon> UniqueIconsT;
    
    UniqueIconsT m_UniqueIcons;
    NSString *m_ParentDir;
    uint32_t m_LastFlushTime;
    
    // Shared between instances. Only grows, does not shrink.
    static TypeIconsT *m_TypeIcons;
    static int m_TypeIconsRefCount;
};

ModernPanelViewPresentation::IconCache::TypeIconsT *ModernPanelViewPresentation::IconCache::m_TypeIcons = nullptr;
int ModernPanelViewPresentation::IconCache::m_TypeIconsRefCount = 0;

///////////////////////////////////////////////////////////////////////////////////////////////////
// class ModernPanelViewPresentation
///////////////////////////////////////////////////////////////////////////////////////////////////

// Item name display insets inside the item line.
// Order: left, top, right, bottom.
const int g_TextInsetsInLine[4] = {7, 0, 5, 1};
// Width of the divider between views.
const int g_DividerWidth = 3;

ModernPanelViewPresentation::ModernPanelViewPresentation()
:   m_DrawIcons(true)
{
    m_IconCache = new IconCache;
    
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
    
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, NSRectToCGRect(_dirty_rect));
    
    DrawView(context);
}

void ModernPanelViewPresentation::OnFrameChanged(NSRect _frame)
{
    m_Size = _frame.size;
    
    // TODO: Temporary hack!
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
    uint64_t curtime = GetTimeInNanoseconds();
    m_IconCache->OnDirectoryChanged(curtime);
}

void ModernPanelViewPresentation::DrawView(CGContextRef _context)
{
    uint64_t curtime = GetTimeInNanoseconds();
    
    auto &sorted_entries = m_State->Data->SortedDirectoryEntries();
    auto &entries = m_State->Data->DirectoryEntries();
    
    ///////////////////////////////////////////////////////////////////////////////
    // Divider.
    CGColorRef divider_stroke_color = CGColorCreateGenericRGB(101/255.0, 101/255.0, 101/255.0, 1.0);
    CGColorRef divider_fill_color = CGColorCreateGenericRGB(174/255.0, 174/255.0, 174/255.0, 1.0);
    
    CGContextSetStrokeColorWithColor(_context, divider_stroke_color);
    if (m_IsLeft)
    {
        float x = m_ItemsArea.origin.x + m_ItemsArea.size.width;
        NSPoint view_divider[2] = {
            NSMakePoint(x + 0.5, 0), NSMakePoint(x + 0.5, m_Size.height)
        };
        CGContextStrokeLineSegments(_context, view_divider, 2);
        
        
        CGContextSetFillColorWithColor(_context, divider_fill_color);
        CGContextFillRect(_context, NSMakeRect(x + 1, 0, g_DividerWidth - 1, m_Size.height));
    }
    else
    {
        NSPoint view_divider[2] = {
            NSMakePoint(g_DividerWidth - 0.5, 0), NSMakePoint(g_DividerWidth - 0.5, m_Size.height)
        };
        CGContextStrokeLineSegments(_context, view_divider, 2);
        
        
        CGContextSetFillColorWithColor(_context, divider_fill_color);
        CGContextFillRect(_context, NSMakeRect(0, 0, g_DividerWidth - 1, m_Size.height));
    }
    
    CGColorRelease(divider_fill_color);
    CGColorRelease(divider_stroke_color);
    
    // If current panel is on the right, then translate all rendering by the divider's width.
    if (!m_IsLeft) CGContextTranslateCTM(_context, g_DividerWidth, 0);
    
    
    ///////////////////////////////////////////////////////////////////////////////
    // Header and footer.
    CGColorRef header_stroke_color = CGColorCreateGenericRGB(102/255.0, 102/255.0, 102/255.0, 1.0);
    int header_height = m_ItemsArea.origin.y;
    
    NSShadow *header_text_shadow = m_ActiveHeaderTextShadow;
    if (!m_State->Active) header_text_shadow = m_InactiveHeaderTextShadow;
    
    CGGradientRef header_gradient = m_ActiveHeaderGradient;
    if (!m_State->Active) header_gradient = m_InactiveHeaderGradient;
    
    // Header gradient.
    CGContextSaveGState(_context);
    NSRect header_rect = NSMakeRect(0, 0, m_ItemsArea.size.width, header_height - 1);
    CGContextAddRect(_context, header_rect);
    CGContextClip(_context);
    CGContextDrawLinearGradient(_context, header_gradient, header_rect.origin,
                                NSMakePoint(header_rect.origin.x, header_rect.origin.y + header_rect.size.height), 0);
    CGContextRestoreGState(_context);
    
    // Header line separator.
    CGContextSetStrokeColorWithColor(_context, header_stroke_color);
    NSPoint header_points[2] = {
        NSMakePoint(0, header_height - 0.5), NSMakePoint(m_ItemsArea.size.width, header_height - 0.5)
    };
    CGContextStrokeLineSegments(_context, header_points, 2);
    
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
    CGContextSaveGState(_context);
    NSRect footer_rect = NSMakeRect(0, footer_y + 1, m_ItemsArea.size.width, header_height - 1);
    CGContextAddRect(_context, footer_rect);
    CGContextClip(_context);
    CGContextDrawLinearGradient(_context, header_gradient, footer_rect.origin,
                                NSMakePoint(footer_rect.origin.x, footer_rect.origin.y + footer_rect.size.height), 0);
    CGContextRestoreGState(_context);
    
    // Footer line separator.
    CGContextSetStrokeColorWithColor(_context, header_stroke_color);
    NSPoint footer_points[2] = {
        NSMakePoint(0, footer_y + 0.5), NSMakePoint(m_ItemsArea.size.width, footer_y + 0.5)
    };
    CGContextStrokeLineSegments(_context, footer_points, 2);
    
    // Footer string.
    // If any number of items are selected, then draw selection stats.
    // Otherwise, draw stats of cursor item.
    if(m_State->Data->GetSelectedItemsCount() != 0)
    {
        UniChar selectionbuf[512];
        size_t sz;
        FormHumanReadableBytesAndFiles(m_State->Data->GetSelectedItemsSizeBytes(), m_State->Data->GetSelectedItemsCount(), selectionbuf, sz);
        
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
        [sel_str drawWithRect:NSMakeRect(offset, footer_y + delta, m_ItemsArea.size.width - 2*offset, m_LineHeight) options:options attributes:footer_text_attr];
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
            [time_str drawWithRect:NSMakeRect(m_ItemsArea.size.width - offset - time_width, footer_y + delta, time_width, m_LineHeight) options:options attributes:footer_text_attr];
            
            NSString *size_str = [NSString stringWithCharacters:size_info length:6];
            [size_str drawWithRect:NSMakeRect(m_ItemsArea.size.width - offset - time_width - size_width, footer_y + delta, size_width, m_LineHeight) options:options attributes:footer_text_attr];
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
    const int items_per_column = GetMaxItemsPerColumn();
    const int max_items = (int)sorted_entries.size();
    
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
    
    const int icon_size = 16;
    const int start_y = m_ItemsArea.origin.y;
    const int columns_count = GetNumberOfItemColumns();
    
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
            CGContextSetStrokeColorWithColor(_context, column_divider_color);
            CGContextSetLineWidth(_context, 1);
            CGContextStrokeLineSegments(_context, points, 2);
        }
        
        int count = 0;
        for (; count < items_per_column && i < max_items; ++count, ++i)
        {
            auto raw_index = sorted_entries[i];
            auto &item = entries[raw_index];
            NSString *item_name = (__bridge NSString *)item.cf_name;
            
            NSRect rect = NSMakeRect(start_x + g_TextInsetsInLine[0],
                                     start_y + count*m_LineHeight + g_TextInsetsInLine[1],
                                     column_width - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                     m_LineHeight - g_TextInsetsInLine[1] - g_TextInsetsInLine[3]);
            
            NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
            
            NSDictionary *cur_item_text_attr = item_text_attr;
            if (m_State->Active && item.cf_isselected())
                cur_item_text_attr = active_selected_item_text_attr;
            
            if (m_DrawIcons)
            {
                rect.origin.x += icon_size + g_TextInsetsInLine[0];
                rect.size.width -= icon_size + g_TextInsetsInLine[0];
            }
            
            // Draw selection background.
            if (item.cf_isselected())
            {
                // Draw selected item.
                if (m_State->Active)
                {
                    int offset = 1;
                    if (m_State->CursorPos == i && m_State->Active) offset = 2;
                    CGContextSetFillColorWithColor(_context, active_selected_item_back);
                    CGContextFillRect(_context, NSMakeRect(start_x + offset, start_y + count*m_LineHeight + offset, column_width - 2*offset, m_LineHeight - 2*offset + 1));
                }
                else
                {
                    CGContextSetFillColorWithColor(_context, inactive_selected_item_back);
                    CGContextFillRect(_context, NSMakeRect(start_x + 1, start_y + count*m_LineHeight + 1, column_width - 2, m_LineHeight - 1));
                }
            }
            
            // Draw cursor.
            if (m_State->CursorPos == i && m_State->Active)
            {
                // Draw as cursor item (only if panel is active).
                CGContextSaveGState(_context);
                CGFloat dashes[2] = { 2, 4 };
                CGContextSetLineDash(_context, 0, dashes, 2);
                CGContextSetStrokeColorWithColor(_context, cursor_frame_color);
                CGContextStrokeRect(_context, NSMakeRect(start_x + 1.5, start_y + count*m_LineHeight + 1.5, column_width - 3, m_LineHeight - 2));
                CGContextRestoreGState(_context);
            }
            
            // Draw stats columns for specific views.
            int spec_col_x = m_ItemsArea.size.width;
            if (m_State->ViewType == PanelViewType::ViewFull)
            {
                UniChar date_info[8], time_info[5];
                FormHumanReadableDateRepresentation8(item.mtime, date_info);
                FormHumanReadableTimeRepresentation5(item.mtime, time_info);
                
                NSRect time_rect = NSMakeRect(
                                              spec_col_x - time_column_width + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              time_column_width - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);
                
                NSString *time_str = [NSString stringWithCharacters:time_info length:5];
                [time_str drawWithRect:time_rect options:options attributes:cur_item_text_attr];
                
                rect.size.width -= time_column_width;
                spec_col_x -= time_column_width;
                
                NSRect date_rect = NSMakeRect(
                                              spec_col_x - date_column_width + g_TextInsetsInLine[0],
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
                NSRect size_rect = NSMakeRect(
                    spec_col_x - size_column_width + g_TextInsetsInLine[0],
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
            
            if (m_DrawIcons)
            {

                NSImageRep *image_rep = m_IconCache->GetIcon(*m_State->Data,  item, raw_index, curtime);
                [image_rep drawInRect:NSMakeRect(start_x + g_TextInsetsInLine[0], start_y + count*m_LineHeight + m_LineHeight - icon_size - 1, icon_size, icon_size) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
            }
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
        CGContextSetStrokeColorWithColor(_context, column_divider_color);
        CGContextSetLineWidth(_context, 1);
        CGContextStrokeLineSegments(_context, points, 2);
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
            CGContextSetStrokeColorWithColor(_context, column_divider_color);
            CGContextSetLineWidth(_context, 1);
            CGContextStrokeLineSegments(_context, points, 2);
        }
    }
    
    CGColorRelease(active_selected_item_back);
    CGColorRelease(inactive_selected_item_back);
    CGColorRelease(active_cursor_item_back);
    CGColorRelease(column_divider_color);
    
    m_IconCache->FlushIfNeeded(curtime);
}
