/* Copyright (c) 2013-2016 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#pragma once

#include <string>

namespace CommonPaths
{    
    // all returned paths will contain a trailing slash
    const std::string &AppBundle() noexcept;
    const std::string &Home() noexcept;
    const std::string &Documents() noexcept;
    const std::string &Desktop() noexcept;
    const std::string &Downloads() noexcept;
    const std::string &Applications() noexcept;
    const std::string &Utilities() noexcept;
    const std::string &Library() noexcept;
    const std::string &Pictures() noexcept;
    const std::string &Music() noexcept;
    const std::string &Movies() noexcept;
    const std::string &Root() noexcept;
    const std::string &AppTemporaryDirectory() noexcept;
    const std::string &StartupCWD() noexcept;
};
