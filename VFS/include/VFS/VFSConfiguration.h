// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.

#pragma once

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
    VFSConfiguration(T _t):
        m_Object( make_shared<Model<T>>( move(_t) ) )
    {
        static_assert( is_class<T>::value, "configuration should be a class/struct" );
    }
    
    const char *Tag() const;
    const char *Junction() const;
    
    /**
     * Returns readable host's address.
     * For example, for native fs it will be "".
     * For PSFS it will be like "psfs:"
     * For FTP it will be like "ftp://127.0.0.1"
     * For archive fs it will be path at parent fs like "/Users/migun/Downloads/1.zip"
     * Default implementation returns JunctionPath()
     */
    const char *VerboseJunction() const;
    bool Equal( const VFSConfiguration &_rhs ) const;
    inline bool operator ==(const VFSConfiguration &_rhs) const { return  Equal(_rhs); }
    inline bool operator !=(const VFSConfiguration &_rhs) const { return !Equal(_rhs); }
    
    template <class T>
    bool IsType() const noexcept
    {
        return dynamic_pointer_cast<const Model<T>>( m_Object ) != nullptr;
    }
    
    template <class T>
    const T &Get() const
    {
        if( auto p = dynamic_pointer_cast<const Model<T>>( m_Object ) )
            return p->obj;
        throw domain_error("invalid configuration request");
    }

    template <class T>
    const T &GetUnchecked() const noexcept
    {
        return static_cast<const Model<T>*>( m_Object.get() )->obj;
    }
    
private:
    struct Concept
    {
        virtual ~Concept() = default;
        virtual const char *Tag() const = 0;
        virtual const char *Junction() const = 0;
        virtual const char *VerboseJunction() const = 0;
        virtual const type_info &TypeID() const noexcept = 0;
        virtual bool Equal( const Concept &_rhs ) const = 0;
    };
    
    template <class T>
    struct Model final : Concept
    {
        T obj;
        
        Model(T _t):
            obj( move(_t) )
        {};
        
        virtual const char *Tag() const
        {
            return obj.Tag();
        }
        
        virtual const char *Junction() const
        {
            return obj.Junction();
        }
        
        virtual const type_info &TypeID() const noexcept
        {
            return typeid( T );
        }
        
        virtual bool Equal( const Concept &_rhs ) const
        {
            auto &rhs = static_cast<const Model<T>&>(_rhs);
            return obj == rhs.obj;
        }
        
        template <typename C>
        static auto VerboseJunctionImpl(const C&t, int) ->
        decltype( t.VerboseJunction(), (const char*)nullptr )
        { return t.VerboseJunction(); }
        
        static const char* VerboseJunctionImpl(const T&t, long)
        { return t.Junction(); }
        
        virtual const char *VerboseJunction() const
        {
            return VerboseJunctionImpl(obj, 0);
        }
    };
    
    shared_ptr<const Concept> m_Object;
};
