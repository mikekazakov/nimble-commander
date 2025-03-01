// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DataBackend.h"
#include <Utility/Encodings.h>
#include <Utility/PathManip.h>

namespace nc::viewer {

DataBackend::DataBackend(std::shared_ptr<nc::vfs::FileWindow> _fw, utility::Encoding _encoding)
    : m_FileWindow(_fw), m_Encoding(_encoding), m_DecodeBuffer(std::make_unique<UniChar[]>(m_FileWindow->WindowSize())),
      m_DecodeBufferIndx(std::make_unique<uint32_t[]>(m_FileWindow->WindowSize()))
{
    assert(utility::IsValidEncoding(_encoding));
    DecodeBuffer();
}

void DataBackend::DecodeBuffer()
{
    assert(utility::BytesForCodeUnit(m_Encoding) <= 2); // TODO: support for UTF-32 in the future
    const bool odd = (utility::BytesForCodeUnit(m_Encoding) == 2) && ((m_FileWindow->WindowPos() & 1) == 1);
    utility::InterpretAsUnichar(m_Encoding,
                                reinterpret_cast<const unsigned char *>(m_FileWindow->Window()) + (odd ? 1 : 0),
                                m_FileWindow->WindowSize() - (odd ? 1 : 0),
                                m_DecodeBuffer.get(),
                                m_DecodeBufferIndx.get(),
                                &m_DecodedBufferSize);
}

utility::Encoding DataBackend::Encoding() const
{
    return m_Encoding;
}

void DataBackend::SetEncoding(utility::Encoding _encoding)
{
    if( _encoding != m_Encoding ) {
        assert(utility::IsValidEncoding(_encoding));
        m_Encoding = _encoding;
        DecodeBuffer();
    }
}

std::expected<void, Error> DataBackend::MoveWindowSync(uint64_t _pos)
{
    if( _pos == m_FileWindow->WindowPos() )
        return {}; // nothing to do

    if( const std::expected<void, Error> ret = m_FileWindow->MoveWindow(_pos); !ret )
        return ret;

    DecodeBuffer();
    return {};
}

std::filesystem::path DataBackend::FileName() const
{
    if( !m_FileWindow->File() ) {
        return {};
    }
    const char *path = m_FileWindow->File()->Path();
    if( path == nullptr ) {
        return {};
    }

    return utility::PathManip::Filename(path);
}

} // namespace nc::viewer
