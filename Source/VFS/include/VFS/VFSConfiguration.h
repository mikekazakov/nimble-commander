// Copyright (C) 2015-2026 Michael Kazakov. Subject to GNU General Public License version 3.

#pragma once

#include <memory>
#include <typeinfo>
#include <stdexcept>

/**
 * Configuration requirements synopsis
 *
 * === required:
 * const char *Tag() const
 * const char *Junction() const
 * bool operator==(const T&) const
 *
 * === optional (diagnosed with SNIFAE):
 * const char *VerboseJunction() const
 */

class VFSConfiguration
{
public:
    template <class T>
    VFSConfiguration(T _t) : m_Object(std::make_shared<Model<T>>(std::move(_t)))
    {
        static_assert(std::is_class_v<T>, "configuration should be a class/struct");
    }

    [[nodiscard]] const char *Tag() const;
    [[nodiscard]] const char *Junction() const;

    /**
     * Returns readable host's address.
     * For example, for native fs it will be "".
     * For PSFS it will be like "psfs:"
     * For FTP it will be like "ftp://127.0.0.1"
     * For archive fs it will be path at parent fs like "/Users/migun/Downloads/1.zip"
     * Default implementation returns JunctionPath()
     */
    [[nodiscard]] const char *VerboseJunction() const;
    [[nodiscard]] bool Equal(const VFSConfiguration &_rhs) const;
    bool operator==(const VFSConfiguration &_rhs) const { return Equal(_rhs); }
    bool operator!=(const VFSConfiguration &_rhs) const { return !Equal(_rhs); }

    template <class T>
    [[nodiscard]] bool IsType() const noexcept
    {
        return std::dynamic_pointer_cast<const Model<T>>(m_Object) != nullptr;
    }

    template <class T>
    [[nodiscard]] const T &Get() const
    {
        if( auto p = std::dynamic_pointer_cast<const Model<T>>(m_Object) )
            return p->obj;
        throw std::domain_error("invalid configuration request");
    }

    template <class T>
    [[nodiscard]] const T &GetUnchecked() const noexcept
    {
        return static_cast<const Model<T> *>(m_Object.get())->obj;
    }

private:
    struct Concept {
        virtual ~Concept() = default;
        [[nodiscard]] virtual const char *Tag() const = 0;
        [[nodiscard]] virtual const char *Junction() const = 0;
        [[nodiscard]] virtual const char *VerboseJunction() const = 0;
        [[nodiscard]] virtual const std::type_info &TypeID() const noexcept = 0;
        [[nodiscard]] virtual bool Equal(const Concept &_rhs) const = 0;
    };

    template <class T>
    struct Model final : Concept {
        T obj;

        Model(T _t) : obj(std::move(_t)) {};

        [[nodiscard]] const char *Tag() const override { return obj.Tag(); }

        [[nodiscard]] const char *Junction() const override { return obj.Junction(); }

        [[nodiscard]] const std::type_info &TypeID() const noexcept override { return typeid(T); }

        [[nodiscard]] bool Equal(const Concept &_rhs) const override
        {
            auto &rhs = static_cast<const Model<T> &>(_rhs);
            return obj == rhs.obj;
        }

        template <typename C>
        static auto VerboseJunctionImpl(const C &t, int /*unused*/)
            -> decltype(t.VerboseJunction(), static_cast<const char *>(nullptr))
        {
            return t.VerboseJunction();
        }

        static const char *VerboseJunctionImpl(const T &t, long /*unused*/) { return t.Junction(); }

        [[nodiscard]] const char *VerboseJunction() const override { return VerboseJunctionImpl(obj, 0); }
    };

    std::shared_ptr<const Concept> m_Object;
};
