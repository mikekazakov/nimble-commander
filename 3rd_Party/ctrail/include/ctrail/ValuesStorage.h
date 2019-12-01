#pragma once

#include <chrono>
#include <cstddef>
#include <string>
#include <memory>

namespace ctrail {

class ValuesStorage {
public:
    using time_point = std::chrono::system_clock::time_point;

    template<class T>
    ValuesStorage(T _impl);
    ValuesStorage(const ValuesStorage &_rhs);
    ValuesStorage(ValuesStorage &&_rhs) noexcept;
    ~ValuesStorage();

    void addValues(time_point _time_point, const std::int64_t* _values,
                           std::size_t _values_number);

    std::size_t timePointsNumber() const;
    time_point timePoint(std::size_t _index) const;
    void copyValuesByTimePoint(std::size_t _index,
                                       std::int64_t* _buffer,
                                       std::size_t _buffer_elements) const;

    std::size_t countersNumber() const;
    const std::string &counterName(std::size_t _index) const;
    void copyValuesByCounter(std::size_t _index, std::int64_t* _buffer,
                                     std::size_t _buffer_elements) const;
                                     
    ValuesStorage& operator=(const ValuesStorage& _rhs);
    ValuesStorage& operator=(ValuesStorage&& _rhs) noexcept;
    
private:
    class Concept;
    template <class T> class Model;
    friend void swap(ValuesStorage &_lhs, ValuesStorage &_rhs) noexcept;
    std::unique_ptr<Concept> m_Impl;    
};

class ValuesStorage::Concept {
public:
    virtual ~Concept() = default; 
    virtual std::unique_ptr<Concept> clone() const = 0;
    
    virtual void addValues(time_point _time_point, const std::int64_t* _values,
                           std::size_t _values_number) = 0;

    virtual std::size_t timePointsNumber() const = 0;
    virtual time_point timePoint(std::size_t _index) const = 0;
    virtual void copyValuesByTimePoint(std::size_t _index,
                                       std::int64_t* _buffer,
                                       std::size_t _buffer_elements) const = 0;

    virtual std::size_t countersNumber() const = 0;
    virtual const std::string& counterName(std::size_t _index) const = 0;
    virtual void copyValuesByCounter(std::size_t _index, std::int64_t* _buffer,
                                     std::size_t _buffer_elements) const = 0;
};

template <class T> class ValuesStorage::Model : public ValuesStorage::Concept {
public:
    Model(T _obj) noexcept;
    std::unique_ptr<Concept> clone() const override;    

    void addValues(time_point _time_point, const std::int64_t* _values,
                           std::size_t _values_number) override;
                           
    std::size_t timePointsNumber() const override;
    time_point timePoint(std::size_t _index) const override;
    void copyValuesByTimePoint(std::size_t _index,
                                       std::int64_t* _buffer,
                                       std::size_t _buffer_elements) const override;

    std::size_t countersNumber() const override;
    const std::string& counterName(std::size_t _index) const override;
    void copyValuesByCounter(std::size_t _index, std::int64_t* _buffer,
                                     std::size_t _buffer_elements) const override;                           

private:
    T m_Obj;
};

template <class T>
ValuesStorage::ValuesStorage(T _impl)
    : m_Impl{std::make_unique<Model<T>>(std::move(_impl))}
{
}

template <class T>
ValuesStorage::Model<T>::Model(T _obj) noexcept : m_Obj{std::move(_obj)}
{
}

template <class T>
std::unique_ptr<ValuesStorage::Concept> ValuesStorage::Model<T>::clone() const
{
    return std::make_unique<Model<T>>(*this); 
}

template <class T>
void ValuesStorage::Model<T>::addValues(time_point _time_point,
                                        const std::int64_t* _values,
                                        std::size_t _values_number)
{
    m_Obj.addValues(_time_point, _values, _values_number);
}

template <class T>
std::size_t ValuesStorage::Model<T>::timePointsNumber() const
{
    return m_Obj.timePointsNumber();
}

template <class T>
ValuesStorage::time_point
ValuesStorage::Model<T>::timePoint(std::size_t _index) const
{
    return m_Obj.timePoint(_index);
}

template <class T>
void ValuesStorage::Model<T>::copyValuesByTimePoint(
    std::size_t _index, std::int64_t* _buffer,
    std::size_t _buffer_elements) const
{
    m_Obj.copyValuesByTimePoint(_index, _buffer, _buffer_elements);
}

template <class T>
std::size_t ValuesStorage::Model<T>::countersNumber() const
{
    return m_Obj.countersNumber();
}

template <class T>
const std::string& ValuesStorage::Model<T>::counterName(std::size_t _index) const
{
    return m_Obj.counterName(_index);
}

template <class T>
void ValuesStorage::Model<T>::copyValuesByCounter(
    std::size_t _index, std::int64_t* _buffer,
    std::size_t _buffer_elements) const
{
    m_Obj.copyValuesByCounter(_index, _buffer, _buffer_elements);
}

} // namespace ctrail
