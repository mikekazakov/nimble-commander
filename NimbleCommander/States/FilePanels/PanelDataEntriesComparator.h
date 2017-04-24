#pragma once

#include "PanelDataSortMode.h"

class VFSListing;
class PanelDataItemVolatileData;

namespace panel {

struct ExternalEntryKey;

class SortPredLessBase
{
public:
    SortPredLessBase(const VFSListing &_items,
                     const vector<PanelDataItemVolatileData>& _vd,
                     PanelDataSortMode _sort_mode);
    
protected:
    int Compare( CFStringRef _1st, CFStringRef _2nd ) const noexcept;
    int Compare( const char *_1st, const char *_2nd ) const noexcept;
    const VFSListing&                       l;
    const vector<PanelDataItemVolatileData>&vd;
    const PanelDataSortMode                 sort_mode;

private:
    const CFStringCompareFlags              str_comp_flags;
    typedef int (*comparison)(const char *, const char *);
    const comparison                        plain_compare;
};

class SortPredLessIndToInd : public SortPredLessBase
{
public:
    SortPredLessIndToInd(const VFSListing &_items,
                         const vector<PanelDataItemVolatileData>& _vd,
                         PanelDataSortMode sort_mode);
    bool operator()(unsigned _1, unsigned _2) const;
private:
    int CompareNames(unsigned _1, unsigned _2) const;
    bool IsLessByName(unsigned _1, unsigned _2) const;
    bool IsLessByNameReversed(unsigned _1, unsigned _2) const;
    bool IsLessByExension(unsigned _1, unsigned _2) const;
    bool IsLessByExensionReversed(unsigned _1, unsigned _2) const;
    bool IsLessByModificationTime(unsigned _1, unsigned _2) const;
    bool IsLessByModificationTimeReversed(unsigned _1, unsigned _2) const;
    bool IsLessByBirthTime(unsigned _1, unsigned _2) const;
    bool IsLessByBirthTimeReversed(unsigned _1, unsigned _2) const;
    bool IsLessByAddedTime(unsigned _1, unsigned _2) const;
    bool IsLessByAddedTimeReversed(unsigned _1, unsigned _2) const;
    bool IsLessBySize(unsigned _1, unsigned _2) const;
    bool IsLessBySizeReversed(unsigned _1, unsigned _2) const;
    bool IsLessByFilesystemRepresentation(unsigned _1, unsigned _2) const;
};

struct SortPredLessIndToKeys : public panel::SortPredLessBase
{
    SortPredLessIndToKeys(const VFSListing &_items,
                          const vector<PanelDataItemVolatileData>& _vd,
                          PanelDataSortMode sort_mode);
    bool operator()(unsigned _1, const ExternalEntryKey &_val2) const;
};

}
