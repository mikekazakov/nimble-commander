//
//  VFSConfiguration.h
//  Files
//
//  Created by Michael G. Kazakov on 10/08/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

/** 
 * Configuration requirements synopsis
 *
 * const char *Tag() const
 * const char *Junction() const
 * bool operator==(const T&) const
 *
 */

class VFSConfiguration
{
public:
    VFSConfiguration();

    template <class T>
    VFSConfiguration(T _t):
        m_Object( make_shared<Model<T>>( move(_t) ) )
    {
        static_assert( is_class<T>::value, "configuration should be a class/struct" );
    }
    
    const char *Tag() const;
    const char *Junction() const;
    bool Equal( const VFSConfiguration &_rhs ) const;
    inline bool operator ==(const VFSConfiguration &_rhs) const { return  Equal(_rhs); }
    inline bool operator !=(const VFSConfiguration &_rhs) const { return !Equal(_rhs); }
    
    template <class T>
    bool IsType() const
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
    const T &GetUnchecked() const
    {
        return static_cast<const Model<T>*>( m_Object.get() )->obj;
    }
    
private:
    struct Concept
    {
        virtual ~Concept() = default;
        virtual const char *Tag() const = 0;
        virtual const char *Junction() const = 0;
        virtual const type_info &TypeID() const = 0;
        virtual bool Equal( const Concept &_rhs ) const = 0;
    };
    
    template <class T>
    struct Model : Concept
    {
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
        
        virtual const type_info &TypeID() const
        {
            return typeid( T );
        }
        
        virtual bool Equal( const Concept &_rhs ) const
        {
            auto &rhs = static_cast<const Model<T>&>(_rhs);
            return obj == rhs.obj;
        }
        
        T obj;
    };
    
    shared_ptr<const Concept> m_Object;
};
