//
//  BigFileViewDataBackend.mm
//  Files
//
//  Created by Michael G. Kazakov on 29.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "BigFileViewDataBackend.h"
#import "Encodings.h"

BigFileViewDataBackend::BigFileViewDataBackend(FileWindow *_fw, int _encoding):
    m_FileWindow(_fw),
    m_Encoding(_encoding),
    m_OnDecoded(0),
    m_DecodedBufferSize(0)
{
    assert(encodings::IsValidEncoding(_encoding));
    m_DecodeBuffer = (UniChar*) calloc(m_FileWindow->WindowSize(), sizeof(UniChar));
    m_DecodeBufferIndx = (uint32_t*) calloc(m_FileWindow->WindowSize(), sizeof(uint32_t));
    
    DecodeBuffer();
}

BigFileViewDataBackend::~BigFileViewDataBackend()
{
    free(m_DecodeBuffer);
    free(m_DecodeBufferIndx);
}

void BigFileViewDataBackend::DecodeBuffer()
{
    assert(encodings::BytesForCodeUnit(m_Encoding) <= 2); // TODO: support for UTF-32 in the future
    bool odd = (encodings::BytesForCodeUnit(m_Encoding) == 2) && ((m_FileWindow->WindowPos() & 1) == 1);
    encodings::InterpretAsUnichar(m_Encoding,
                                  (unsigned char*)m_FileWindow->Window() + (odd ? 1 : 0),
                                  m_FileWindow->WindowSize() - (odd ? 1 : 0),
                                  m_DecodeBuffer,
                                  m_DecodeBufferIndx,
                                  &m_DecodedBufferSize);
    if(m_OnDecoded)
        m_OnDecoded();
}

void BigFileViewDataBackend::SetOnDecoded(void (^_handler)())
{
    m_OnDecoded = _handler;
}

int BigFileViewDataBackend::Encoding() const
{
    return m_Encoding;
}

void BigFileViewDataBackend::SetEncoding(int _encoding)
{
    if(_encoding != m_Encoding)
    {
        assert(encodings::IsValidEncoding(_encoding));
        m_Encoding = _encoding;
        DecodeBuffer();
    }
}

int BigFileViewDataBackend::MoveWindowSync(uint64_t _pos)
{
    if(_pos == m_FileWindow->WindowPos())
        return 0; // nothing to do
    
    int ret = m_FileWindow->MoveWindow(_pos);
    if(ret < 0)
        return ret;
    
    DecodeBuffer();
    return 0;
}
