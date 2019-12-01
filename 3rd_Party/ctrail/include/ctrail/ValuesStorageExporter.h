#pragma once

#include <ctrail/ValuesStorage.h>
#include <string>
#include <memory>

namespace ctrail {

class ValuesStorageExporter
{
public:
    enum class Options {
        none = 0,
        differential = 1,
        skip_idle_counters = 2
    };
    template <class T>
    explicit ValuesStorageExporter(T _impl);
    ValuesStorageExporter(const ValuesStorageExporter& _rhs);
    ValuesStorageExporter(ValuesStorageExporter&& _rhs) noexcept;
    
    std::string format(const ValuesStorage &_values, Options _options = Options::none) const;
    
    ValuesStorageExporter &operator=(const ValuesStorageExporter &_rhs);
    ValuesStorageExporter &operator=(ValuesStorageExporter &&_rhs) noexcept;
    
private:
    class Concept;
    template <class T> class Model;
    std::unique_ptr<Concept> m_Impl;
};
    
class ValuesStorageExporter::Concept {
public:
    virtual ~Concept() = default;
    virtual std::unique_ptr<Concept> clone() const = 0;
    virtual std::string format(const ValuesStorage &_values, Options _options) const = 0;
};
    
template <class T> class ValuesStorageExporter::Model : public ValuesStorageExporter::Concept {
public:
    Model(T _obj) noexcept;
    std::unique_ptr<Concept> clone() const override;
    std::string format(const ValuesStorage &_values, Options _options) const override;
private:
    T m_Obj;
};

inline ValuesStorageExporter::Options operator|(ValuesStorageExporter::Options _lhs,
                                              ValuesStorageExporter::Options _rhs) noexcept
{
    return static_cast<ValuesStorageExporter::Options>(static_cast<int>(_lhs) |
                                                     static_cast<int>(_rhs) );
}

inline ValuesStorageExporter::Options operator&(ValuesStorageExporter::Options _lhs,
                                              ValuesStorageExporter::Options _rhs) noexcept
{
    return static_cast<ValuesStorageExporter::Options>(static_cast<int>(_lhs) &
                                                     static_cast<int>(_rhs) );
}

inline ValuesStorageExporter::Options operator~(ValuesStorageExporter::Options _val) noexcept
{
    return static_cast<ValuesStorageExporter::Options>(~(static_cast<int>(_val)));
}

template <class T>
ValuesStorageExporter::ValuesStorageExporter(T _impl):
    m_Impl(std::make_unique<Model<T>>(std::move(_impl)))
{
}

template <class T>
ValuesStorageExporter::Model<T>::Model(T _obj) noexcept: m_Obj{std::move(_obj)}
{}

template <class T>
std::unique_ptr<ValuesStorageExporter::Concept>
    ValuesStorageExporter::Model<T>::clone() const
{
    return std::make_unique<Model>(m_Obj);
}
    
template <class T>
std::string ValuesStorageExporter::Model<T>::format(const ValuesStorage &_values,
                                                  Options _options) const
{
    return m_Obj.format(_values, _options);
}

}
