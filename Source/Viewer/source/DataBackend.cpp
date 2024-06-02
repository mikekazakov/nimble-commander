// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DataBackend.h"
#include <Utility/Encodings.h>
#include <Utility/PathManip.h>

namespace nc::viewer {

DataBackend::DataBackend(std::shared_ptr<nc::vfs::FileWindow> _fw, int _encoding)
    : m_FileWindow(_fw), m_Encoding(_encoding), m_DecodeBuffer(std::make_unique<UniChar[]>(m_FileWindow->WindowSize())),
      m_DecodeBufferIndx(std::make_unique<uint32_t[]>(m_FileWindow->WindowSize()))
{
    assert(encodings::IsValidEncoding(_encoding));
    DecodeBuffer();
}

void DataBackend::DecodeBuffer()
{
    assert(encodings::BytesForCodeUnit(m_Encoding) <= 2); // TODO: support for UTF-32 in the future
    bool odd = (encodings::BytesForCodeUnit(m_Encoding) == 2) && ((m_FileWindow->WindowPos() & 1) == 1);
    encodings::InterpretAsUnichar(m_Encoding,
                                  reinterpret_cast<const unsigned char *>(m_FileWindow->Window()) + (odd ? 1 : 0),
                                  m_FileWindow->WindowSize() - (odd ? 1 : 0),
                                  m_DecodeBuffer.get(),
                                  m_DecodeBufferIndx.get(),
                                  &m_DecodedBufferSize);
}

int DataBackend::Encoding() const
{
    return m_Encoding;
}

void DataBackend::SetEncoding(int _encoding)
{
    if( _encoding != m_Encoding ) {
        assert(encodings::IsValidEncoding(_encoding));
        m_Encoding = _encoding;
        DecodeBuffer();
    }
}

int DataBackend::MoveWindowSync(uint64_t _pos)
{
    if( _pos == m_FileWindow->WindowPos() )
        return 0; // nothing to do

    int ret = m_FileWindow->MoveWindow(_pos);
    if( ret < 0 )
        return ret;

    DecodeBuffer();
    return 0;
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
