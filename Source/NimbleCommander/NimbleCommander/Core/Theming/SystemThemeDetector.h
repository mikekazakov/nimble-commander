// Copyright (C) 2022-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Appearance.h"
#include <Base/Observable.h>

namespace nc {

class SystemThemeDetector : base::ObservableBase
{
public:
    using ObservationTicket = ObservableBase::ObservationTicket;

    SystemThemeDetector();
    ~SystemThemeDetector();

    ThemeAppearance SystemAppearance() const noexcept;

    ObservationTicket ObserveChanges(std::function<void()> _callback);

private:
    struct Impl;
    void OnChanged();
    std::unique_ptr<Impl> I;
};

} // namespace nc
