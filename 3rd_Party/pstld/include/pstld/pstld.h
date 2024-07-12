// Copyright (c) Michael G. Kazakov. All rights reserved. Distributed under the MIT License.
#pragma once

#if defined(PSTLD_INTERNAL_DO_HACK_INTO_STD) || defined(PSTLD_INTERNAL_HEADER_ONLY) ||             \
    defined(PSTLD_INTERNAL_IMPL) || defined(PSTLD_INTERNAL_ARC)
    #error internal settings can't be defined manually
#endif

#if defined(PSTLD_HACK_INTO_STD)
    #define PSTLD_INTERNAL_DO_HACK_INTO_STD
#endif

#if defined(PSTLD_HEADER_ONLY)
    #define PSTLD_INTERNAL_HEADER_ONLY
#endif

#if defined(PSTLD_INTERNAL_HEADER_ONLY)
    #define PSTLD_INTERNAL_IMPL inline
#else
    #define PSTLD_INTERNAL_IMPL
#endif

#if defined(PSTLD_INTERNAL_HEADER_ONLY) && __has_feature(objc_arc)
    #define PSTLD_INTERNAL_ARC
#endif

#if defined(PSTLD_INTERNAL_HEADER_ONLY)
    #include <dispatch/dispatch.h>
#endif

#include <algorithm>
#include <numeric>
#include <iterator>
#include <vector>
#include <limits>
#include <mutex>
#include <cstddef>
#include <thread>
#include <type_traits>
#include <atomic>

namespace pstld {

// To avoid ODR violations when NonARC and ARC builds are mixed together - the ARC symbols are
// placed into a nested inline namespace.
#if defined(PSTLD_INTERNAL_ARC)
inline namespace arc {
#endif

//--------------------------------------------------------------------------------------------------
//
// Common facilities
//
//--------------------------------------------------------------------------------------------------

namespace internal {

inline constexpr size_t chunks_per_cpu = 8;
inline constexpr size_t insertion_sort_limit = 32;
inline constexpr size_t merge_parallel_limit = 8192;
inline constexpr size_t hardware_destructive_interference_size = 128; // or 64 on x86

size_t max_hw_threads() noexcept;

void dispatch_apply(size_t iterations, void *ctx, void (*function)(void *, size_t)) noexcept;
void dispatch_async(void *ctx, void (*function)(void *)) noexcept;

class DispatchGroup
{
public:
    DispatchGroup() noexcept;
    DispatchGroup(const DispatchGroup &) = delete;
    ~DispatchGroup();

    void dispatch(void *ctx, void (*function)(void *)) noexcept;
    void wait() noexcept;

private:
#if defined(PSTLD_INTERNAL_ARC)
    __strong dispatch_group_t m_group;
    __strong dispatch_queue_global_t m_queue;
#else
    void *m_group;
    void *m_queue;
#endif
};

template <class It>
using iterator_category_t = typename std::iterator_traits<It>::iterator_category;

template <class It>
inline constexpr bool is_random_iterator_v =
    std::is_convertible_v<iterator_category_t<It>, std::random_access_iterator_tag>;

template <class It>
inline constexpr bool is_bidirectional_iterator_v =
    std::is_convertible_v<iterator_category_t<It>, std::bidirectional_iterator_tag>;

template <class It>
using iterator_value_t = typename std::iterator_traits<It>::value_type;

template <class It>
using iterator_diff_t = typename std::iterator_traits<It>::difference_type;

template <class T>
inline constexpr bool can_be_atomic_v = std::conjunction_v<std::is_trivially_copyable<T>,
                                                           std::is_copy_constructible<T>,
                                                           std::is_move_constructible<T>,
                                                           std::is_copy_assignable<T>,
                                                           std::is_move_assignable<T>>;

struct no_op {
    template <typename T>
    T &&operator()(T &&v) const
    {
        return std::forward<T>(v);
    }
};

struct parallelism_exception : std::exception {
    const char *what() const noexcept override;
    [[noreturn]] static void raise();
};

template <class T>
struct parallelism_allocator {
    using value_type = T;
    using size_type = size_t;
    using difference_type = ptrdiff_t;

    T *allocate(size_t count)
    {
        if( void *ptr = ::operator new(count * sizeof(T), std::nothrow) )
            return static_cast<T *>(ptr);
        else
            parallelism_exception::raise();
    }

    void deallocate(T *ptr, size_t count) noexcept { ::operator delete(ptr, count * sizeof(T)); }

    template <class Other>
    bool operator==(const parallelism_allocator<Other> &) const noexcept
    {
        return true;
    }

    template <class Other>
    bool operator!=(const parallelism_allocator<Other> &) const noexcept
    {
        return false;
    }
};

template <class T>
using parallelism_vector = std::vector<T, parallelism_allocator<T>>;

template <class T>
struct unitialized_array : parallelism_allocator<T> {
    using allocator = parallelism_allocator<T>;
    T *m_data;
    size_t m_size;
    unitialized_array(size_t size) : m_data(allocator::allocate(size)), m_size(size) {}

    ~unitialized_array()
    {
        std::destroy(m_data, m_data + m_size);
        allocator::deallocate(m_data, m_size);
    }

    template <class... Args>
    void put(size_t ind, Args &&...vals) noexcept
    {
        ::new(m_data + ind) T(std::forward<Args>(vals)...);
    }

    T *begin() noexcept { return m_data; }

    T *end() noexcept { return m_data + m_size; }

    T &operator[](size_t ind) noexcept { return m_data[ind]; }
};

template <class T>
constexpr size_t work_chunks_min_fraction_1(T count)
{
    return std::min(max_hw_threads() * chunks_per_cpu, static_cast<size_t>(count));
}

template <class T>
constexpr size_t work_chunks_min_fraction_2(T count)
{
    return std::min(max_hw_threads() * chunks_per_cpu, static_cast<size_t>(count / 2));
}

template <class It>
struct ItRange {
    It first;
    It last;
};

template <class It, bool Forward = true, bool IsRandomAccess = is_random_iterator_v<It>>
struct Partition;

template <class It, bool Forward>
struct Partition<It, Forward, true> {
    It base;
    size_t fraction;
    size_t leftover;
    size_t count;
    Partition(It first, size_t count, size_t chunks) noexcept
        : base(first), fraction(count / chunks), leftover(count % chunks), count(count)
    {
    }

    ItRange<It> at(size_t chunk_no) const noexcept
    {
        if( leftover ) {
            if( chunk_no >= leftover ) {
                const auto first =
                    advance(base, (fraction + 1) * leftover + fraction * (chunk_no - leftover));
                const auto last = advance(first, fraction);
                return {first, last};
            }
            else {
                const auto first = advance(base, (fraction + 1) * chunk_no);
                const auto last = advance(first, fraction + 1);
                return {first, last};
            }
        }
        else {
            const auto first = advance(base, fraction * chunk_no);
            const auto last = advance(first, fraction);
            return {first, last};
        }
    }

    It end() const noexcept { return base + count; }

    static It advance(It it, size_t distance) noexcept
    {
        if constexpr( Forward )
            return it + distance;
        else
            return it - distance;
    }
};

template <class It, bool Forward>
struct Partition<It, Forward, false> {
    parallelism_vector<ItRange<It>> segments;
    Partition(It first, size_t count, size_t chunks) : segments(chunks)
    {
        size_t fraction = count / chunks;
        size_t leftover = count % chunks;
        It it = first;
        for( size_t i = 0; i != chunks; ++i ) {
            auto diff = fraction;
            if( leftover != 0 ) {
                ++diff;
                --leftover;
            }
            auto last = advance(it, diff);
            segments[i] = {it, last};
            it = last;
        }
    }

    ItRange<It> at(size_t chunk_no) const noexcept { return segments[chunk_no]; }

    It end() const noexcept { return segments.back().last; }

    static It advance(It it, size_t distance) noexcept
    {
        if constexpr( Forward )
            return std::next(it, distance);
        else
            return std::prev(it, distance);
    }
};

template <class It, bool = is_random_iterator_v<It> &&can_be_atomic_v<It>>
struct MinIteratorResult;

template <class It>
struct MinIteratorResult<It, true> {
    std::atomic<size_t> min_chunk;
    std::atomic<It> min;
    MinIteratorResult(It last) : min_chunk{std::numeric_limits<size_t>::max()}, min{last} {}

    void put(size_t chunk, It it)
    {
        It prev_it = min;
        while( prev_it > it && !min.compare_exchange_weak(prev_it, it) )
            ;

        size_t prev_chunk = min_chunk;
        while( prev_chunk > chunk && !min_chunk.compare_exchange_weak(prev_chunk, chunk) )
            ;
    }
};

template <class It>
struct MinIteratorResult<It, false> {
    std::atomic<size_t> min_chunk;
    It min;
    std::mutex mutex;

    MinIteratorResult(It last) : min_chunk{std::numeric_limits<size_t>::max()}, min{last} {}

    void put(size_t chunk, It it)
    {
        size_t prev = std::numeric_limits<size_t>::max();
        while( !min_chunk.compare_exchange_weak(prev, chunk) )
            if( prev < chunk )
                return;

        std::lock_guard lock{mutex};
        if( min_chunk == chunk )
            min = it;
    }
};

template <class It, bool = is_random_iterator_v<It> &&can_be_atomic_v<It>>
struct MaxIteratorResult;

template <class It>
struct MaxIteratorResult<It, true> {
    std::atomic<size_t> max_chunk;
    std::atomic<It> max;
    It last;

    MaxIteratorResult(It last)
        : max_chunk{std::numeric_limits<size_t>::max()}, max{last}, last(last)
    {
    }

    void put(size_t chunk, It it)
    {
        It prev_it = max;
        while( (prev_it == last || prev_it < it) && !max.compare_exchange_weak(prev_it, it) )
            ;

        size_t prev_chunk = max_chunk;
        while( static_cast<ptrdiff_t>(prev_chunk) < static_cast<ptrdiff_t>(chunk) &&
               !max_chunk.compare_exchange_weak(prev_chunk, chunk) )
            ;
    }
};

template <class It>
struct MaxIteratorResult<It, false> {
    std::atomic<size_t> max_chunk;
    It max;
    std::mutex mutex;

    MaxIteratorResult(It last) : max_chunk{std::numeric_limits<size_t>::max()}, max{last} {}

    void put(size_t chunk, It it)
    {
        size_t prev = std::numeric_limits<size_t>::max();
        while( !max_chunk.compare_exchange_weak(prev, chunk) )
            if( prev > chunk )
                return;

        std::lock_guard lock{mutex};
        if( max_chunk == chunk )
            max = it;
    }
};

template <class T>
struct Dispatchable {
    static void dispatch(void *ctx, size_t ind) noexcept { static_cast<T *>(ctx)->run(ind); }
    void dispatch_apply(size_t count) noexcept { internal::dispatch_apply(count, this, dispatch); }
};

template <class T>
struct Dispatchable2 {
    static void dispatch_first(void *ctx, size_t ind) noexcept
    {
        static_cast<T *>(ctx)->run_first(ind);
    }
    void dispatch_apply_first(size_t count) noexcept
    {
        internal::dispatch_apply(count, this, dispatch_first);
    }
    static void dispatch_second(void *ctx, size_t ind) noexcept
    {
        static_cast<T *>(ctx)->run_second(ind);
    }
    void dispatch_apply_second(size_t count) noexcept
    {
        internal::dispatch_apply(count, this, dispatch_second);
    }
};

template <class T>
struct CircularArray {
    static_assert(std::is_trivial_v<T>);
    static constexpr size_t default_log_size = 6;

    size_t m_log_size;
    std::atomic_int64_t m_ref_count;

    static CircularArray *alloc(size_t log_size = default_log_size)
    {
        static_assert(sizeof(T) >= sizeof(CircularArray));

        size_t count = static_cast<size_t>(1) << log_size;
        size_t bytes = sizeof(T) * (count + 1);

        auto buffer = static_cast<CircularArray *>(::operator new(bytes, std::nothrow));
        if( buffer == nullptr )
            parallelism_exception::raise();

        buffer->m_log_size = log_size;
        buffer->m_ref_count = 1;
        return buffer;
    }

    void retain() noexcept { ++m_ref_count; }

    void release() noexcept
    {
        if( --m_ref_count == 0 )
            ::operator delete(this);
    }

    T &operator[](size_t ind) noexcept
    {
        auto elements = reinterpret_cast<T *>(this) + 1;
        auto mask = (static_cast<size_t>(1) << m_log_size) - 1;
        return elements[ind & mask];
    }

    constexpr size_t size() noexcept { return static_cast<size_t>(1) << m_log_size; }

    CircularArray *grow(size_t bottom, size_t top)
    {
        auto grown = alloc(m_log_size + 1);
        for( size_t ind = top; ind != bottom; ++ind )
            (*grown)[ind] = (*this)[ind];
        return grown;
    }
};

template <class T>
struct alignas(hardware_destructive_interference_size) CircularWorkStealingDeque {
    std::atomic<size_t> m_bottom{0};
    std::atomic<size_t> m_top{0};
    CircularArray<T> *m_array{CircularArray<T>::alloc()};
    std::mutex m_mut;

    CircularWorkStealingDeque() = default;
    CircularWorkStealingDeque(const CircularWorkStealingDeque &) = delete;
    CircularWorkStealingDeque &operator=(const CircularWorkStealingDeque &) = delete;
    ~CircularWorkStealingDeque() { m_array->release(); }

    void push_bottom(const T &val)
    {
        size_t bottom = m_bottom.load();
        size_t top = m_top.load();
        size_t size = bottom - top;
        if( size >= m_array->size() ) {
            CircularArray<T> *grown = m_array->grow(bottom, top);
            CircularArray<T> *current;
            {
                std::lock_guard lock{m_mut};
                current = std::exchange(m_array, grown);
            }
            current->release();
        }
        (*m_array)[bottom] = val;
        m_bottom.store(bottom + 1);
    }

    bool pop_bottom(T &val) noexcept
    {
        size_t bottom = m_bottom.load();
        if( bottom == 0 )
            return false;
        --bottom;
        m_bottom.store(bottom);
        size_t top = m_top.load();
        if( bottom < top ) {
            m_bottom.store(top);
            return false;
        }

        val = (*m_array)[bottom];

        if( bottom > top )
            return true;

        if( m_top.compare_exchange_strong(top, top + 1) ) {
            m_bottom.store(top + 1);
            return true;
        }
        else {
            m_bottom.store(top);
            return false;
        }
    }

    bool steal_top(T &val) noexcept
    {
        size_t top = m_top.load();
        while( true ) {
            if( m_bottom.load() <= top )
                return false;
            CircularArray<T> *current;
            {
                std::lock_guard lock{m_mut};
                current = m_array;
                current->retain();
            }
            val = (*current)[top];
            current->release();
            if( m_top.compare_exchange_strong(top, top + 1) )
                return true;
        }
    }
};

struct alignas(hardware_destructive_interference_size) WorkCounter {
    std::atomic<size_t> m_done{0};
    void commit_relaxed(size_t newly_done) noexcept
    {
        size_t done = m_done.load(std::memory_order_relaxed);
        m_done.store(done + newly_done, std::memory_order_relaxed);
    }
    size_t load_relaxed() noexcept { return m_done.load(std::memory_order_relaxed); }
};

} // namespace internal

//--------------------------------------------------------------------------------------------------
//
// Algorithms implementation
//
//--------------------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------------------
// reduce, transform_reduce
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class T, class BinOp, class UnOp>
struct TransformReduce : Dispatchable<TransformReduce<It, T, BinOp, UnOp>> {
    Partition<It> m_partition;
    unitialized_array<T> m_results;
    BinOp m_reduce;
    UnOp m_transform;

    TransformReduce(size_t count, size_t chunks, It first, BinOp reduce_op, UnOp transform_op)
        : m_partition(first, count, chunks), m_results(chunks), m_reduce(reduce_op),
          m_transform(transform_op)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p = m_partition.at(ind);
        m_results.put(ind, transform_reduce_at_least_2(p.first, p.last));
    }

    T transform_reduce_at_least_2(It first, It last)
    {
        auto next = first;
        T val = m_reduce(m_transform(*first), m_transform(*++next));
        while( ++next != last )
            val = m_reduce(std::move(val), m_transform(*next));
        return val;
    }
};

template <class It, class T, class BinOp>
T move_reduce(It first, It last, T val, BinOp reduce)
{
    for( ; first != last; ++first )
        val = reduce(std::move(val), std::move(*first));
    return val;
}

template <class It, class T, class BinOp, class UnOp>
T move_transform_reduce(It first, It last, T val, BinOp reduce, UnOp transform)
{
    for( ; first != last; ++first )
        val = reduce(std::move(val), transform(std::move(*first)));
    return val;
}

} // namespace internal

template <class FwdIt, class T, class BinOp, class UnOp>
T transform_reduce(FwdIt first, FwdIt last, T val, BinOp reduce_op, UnOp transform_op) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_2(count);
    if( chunks > 1 ) {
        try {
            internal::TransformReduce<FwdIt, T, BinOp, UnOp> op{
                static_cast<size_t>(count), chunks, first, reduce_op, transform_op};
            op.dispatch_apply(chunks);
            return internal::move_reduce(
                op.m_results.begin(), op.m_results.end(), std::move(val), reduce_op);
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return internal::move_transform_reduce(first, last, std::move(val), reduce_op, transform_op);
}

template <class It>
internal::iterator_value_t<It> reduce(It first, It last) noexcept
{
    using T = internal::iterator_value_t<It>;
    return ::pstld::transform_reduce(first, last, T{}, std::plus<>{}, ::pstld::internal::no_op{});
}

template <class It, class T>
T reduce(It first, It last, T val) noexcept
{
    return ::pstld::transform_reduce(
        first, last, std::move(val), std::plus<>{}, ::pstld::internal::no_op{});
}

template <class It, class T, class BinOp>
T reduce(It first, It last, T val, BinOp op) noexcept
{
    return ::pstld::transform_reduce(first, last, std::move(val), op, ::pstld::internal::no_op{});
}

namespace internal {

template <class It1, class It2, class T, class BinRedOp, class BinTrOp>
struct TransformReduce2 : Dispatchable<TransformReduce2<It1, It2, T, BinRedOp, BinTrOp>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;
    unitialized_array<T> m_results;
    BinRedOp m_reduce;
    BinTrOp m_transform;

    TransformReduce2(size_t count,
                     size_t chunks,
                     It1 first1,
                     It2 first2,
                     BinRedOp reduce_op,
                     BinTrOp transform_op)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks),
          m_results(chunks), m_reduce(reduce_op), m_transform(transform_op)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p1 = m_partition1.at(ind);
        auto p2 = m_partition2.at(ind);
        m_results.put(ind, transform_reduce_at_least_2(p1.first, p1.last, p2.first));
    }

    T transform_reduce_at_least_2(It1 first1, It1 last1, It2 first2)
    {
        auto next1 = first1;
        auto next2 = first2;
        T val = m_reduce(m_transform(*first1, *first2), m_transform(*++next1, *++next2));
        while( ++next1 != last1 )
            val = m_reduce(std::move(val), m_transform(*next1, *++next2));
        return val;
    }
};

template <class It1, class It2, class T, class BinOp, class UnOp>
T move_transform_reduce(It1 first1, It1 last1, It2 first2, T val, BinOp reduce, UnOp transform)
{
    for( ; first1 != last1; ++first1, ++first2 )
        val = reduce(std::move(val), transform(std::move(*first1), std::move(*first2)));
    return val;
}

} // namespace internal

template <class FwdIt1, class FwdIt2, class T, class BinRedOp, class BinTrOp>
T transform_reduce(FwdIt1 first1,
                   FwdIt1 last1,
                   FwdIt2 first2,
                   T val,
                   BinRedOp reduce_op,
                   BinTrOp transform_op) noexcept
{
    const auto count = std::distance(first1, last1);
    const auto chunks = internal::work_chunks_min_fraction_2(count);
    if( chunks > 1 ) {
        try {
            internal::TransformReduce2<FwdIt1, FwdIt2, T, BinRedOp, BinTrOp> op{
                static_cast<size_t>(count), chunks, first1, first2, reduce_op, transform_op};
            op.dispatch_apply(chunks);
            return internal::move_reduce(
                op.m_results.begin(), op.m_results.end(), std::move(val), reduce_op);
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return internal::move_transform_reduce(
        first1, last1, first2, std::move(val), reduce_op, transform_op);
}

template <class It1, class It2, class T>
T transform_reduce(It1 first1, It1 last1, It2 first2, T val) noexcept
{
    return ::pstld::transform_reduce(
        first1, last1, first2, std::move(val), std::plus<>{}, std::multiplies<>{});
}

//--------------------------------------------------------------------------------------------------
// all_of, none_of, any_of
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class UnPred, bool Expected, bool Init>
struct AllOf : Dispatchable<AllOf<It, UnPred, Expected, Init>> {
    Partition<It> m_partition;
    UnPred m_pred;
    std::atomic_bool m_done{false};
    bool m_result = Init;

    AllOf(size_t count, size_t chunks, It first, UnPred pred)
        : m_partition(first, count, chunks), m_pred(pred)
    {
    }

    void run(size_t ind) noexcept
    {
        if( m_done )
            return;
        for( auto p = m_partition.at(ind); p.first != p.last; ++p.first )
            if( static_cast<bool>(m_pred(*p.first)) == !Expected ) {
                m_done = true;
                m_result = !Init;
                return;
            }
    }
};

} // namespace internal

template <class FwdIt, class UnPred>
bool all_of(FwdIt first, FwdIt last, UnPred pred) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::AllOf<FwdIt, UnPred, true, true> op{
                static_cast<size_t>(count), chunks, first, pred};
            op.dispatch_apply(chunks);
            return op.m_result;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::all_of(first, last, pred);
}

template <class FwdIt, class UnPred>
bool none_of(FwdIt first, FwdIt last, UnPred pred) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::AllOf<FwdIt, UnPred, false, true> op{
                static_cast<size_t>(count), chunks, first, pred};
            op.dispatch_apply(chunks);
            return op.m_result;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::none_of(first, last, pred);
}

template <class FwdIt, class UnPred>
bool any_of(FwdIt first, FwdIt last, UnPred pred) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::AllOf<FwdIt, UnPred, false, false> op{
                static_cast<size_t>(count), chunks, first, pred};
            op.dispatch_apply(chunks);
            return op.m_result;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::any_of(first, last, pred);
}

//--------------------------------------------------------------------------------------------------
// for_each, for_each_n
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Func>
struct ForEach : Dispatchable<ForEach<It, Func>> {
    Partition<It> m_partition;
    Func m_func;

    ForEach(size_t count, size_t chunks, It first, Func func)
        : m_partition(first, count, chunks), m_func(func)
    {
    }

    void run(size_t ind) noexcept
    {
        for( auto p = m_partition.at(ind); p.first != p.last; ++p.first )
            m_func(*p.first);
    }
};

} // namespace internal

template <class FwdIt, class Func>
void for_each(FwdIt first, FwdIt last, Func func) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::ForEach<FwdIt, Func> op{static_cast<size_t>(count), chunks, first, func};
            op.dispatch_apply(chunks);
            return;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    std::for_each(first, last, func);
}

template <class FwdIt, class Size, class Func>
FwdIt for_each_n(FwdIt first, Size count, Func func) noexcept
{
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::ForEach<FwdIt, Func> op{static_cast<size_t>(count), chunks, first, func};
            op.dispatch_apply(chunks);
            return op.m_partition.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::for_each_n(first, count, func);
}

//--------------------------------------------------------------------------------------------------
// count, count_if
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Pred>
struct Count : Dispatchable<Count<It, Pred>> {
    Partition<It> m_partition;
    Pred m_pred;
    std::atomic<iterator_diff_t<It>> m_result{};

    Count(size_t count, size_t chunks, It first, Pred pred)
        : m_partition(first, count, chunks), m_pred(pred)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p = m_partition.at(ind);
        m_result += std::count_if(p.first, p.last, m_pred);
    }
};

} // namespace internal

template <class FwdIt, class Pred>
typename std::iterator_traits<FwdIt>::difference_type
count_if(FwdIt first, FwdIt last, Pred pred) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Count<FwdIt, Pred> op{static_cast<size_t>(count), chunks, first, pred};
            op.dispatch_apply(chunks);
            return op.m_result;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::count_if(first, last, pred);
}

template <class FwdIt, class T>
typename std::iterator_traits<FwdIt>::difference_type
count(FwdIt first, FwdIt last, const T &value) noexcept
{
    return ::pstld::count_if(
        first, last, [&value](const auto &iter_value) { return iter_value == value; });
}

//--------------------------------------------------------------------------------------------------
// find, find_if, find_if_not, find_first_of
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Pred>
struct Find : Dispatchable<Find<It, Pred>> {
    Partition<It> m_partition;
    MinIteratorResult<It> m_result;
    Pred m_pred;

    Find(size_t count, size_t chunks, It first, It last, Pred pred)
        : m_partition(first, count, chunks), m_result{last}, m_pred(pred)
    {
    }

    void run(size_t ind) noexcept
    {
        if( ind < m_result.min_chunk ) {
            auto p = m_partition.at(ind);
            auto it = std::find_if(p.first, p.last, m_pred);
            if( it != p.last )
                m_result.put(ind, it);
        }
    }
};

} // namespace internal

template <class FwdIt, class Pred>
FwdIt find_if(FwdIt first, FwdIt last, Pred pred) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Find<FwdIt, Pred> op{static_cast<size_t>(count), chunks, first, last, pred};
            op.dispatch_apply(chunks);
            return op.m_result.min;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::find_if(first, last, pred);
}

template <class FwdIt, class T>
FwdIt find(FwdIt first, FwdIt last, const T &value) noexcept
{
    return ::pstld::find_if(
        first, last, [&value](const auto &iter_value) { return iter_value == value; });
}

template <class FwdIt, class Pred>
FwdIt find_if_not(FwdIt first, FwdIt last, Pred pred) noexcept
{
    return ::pstld::find_if(
        first, last, [&pred](const auto &value) { return !static_cast<bool>(pred(value)); });
}

template <class FwdIt1, class FwdIt2>
FwdIt1 find_first_of(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2) noexcept
{
    return ::pstld::find_if(first1, last1, [first2, last2](const auto &value) {
        return std::find(first2, last2, value) != last2;
    });
}

template <class FwdIt1, class FwdIt2, class Pred>
FwdIt1 find_first_of(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2, Pred pred) noexcept
{
    return ::pstld::find_if(first1, last1, [first2, last2, &pred](const auto &value1) {
        return std::find_if(first2, last2, [&value1, &pred](const auto &value2) {
                   return static_cast<bool>(pred(value1, value2));
               }) != last2;
    });
}

//--------------------------------------------------------------------------------------------------
// adjacent_find
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Pred>
struct AdjacentFind : Dispatchable<AdjacentFind<It, Pred>> {
    Partition<It> m_partition;
    MinIteratorResult<It> m_result;
    Pred m_pred;

    AdjacentFind(size_t count, size_t chunks, It first, It last, Pred pred)
        : m_partition(first, count, chunks), m_result{last}, m_pred(pred)
    {
    }

    void run(size_t ind) noexcept
    {
        if( ind < m_result.min_chunk ) {
            auto p = m_partition.at(ind);
            for( auto it1 = p.first, it2 = p.first; it1 != p.last; it1 = it2 ) {
                ++it2;
                if( m_pred(*it1, *it2) ) {
                    m_result.put(ind, it1);
                    return;
                }
            }
        }
    }
};

} // namespace internal

template <class FwdIt, class Pred>
FwdIt adjacent_find(FwdIt first, FwdIt last, Pred pred) noexcept
{
    const auto count = std::distance(first, last);
    if( count > 1 ) {
        const auto chunks = internal::work_chunks_min_fraction_1(count - 1);
        if( chunks > 1 ) {
            try {
                internal::AdjacentFind<FwdIt, Pred> op{
                    static_cast<size_t>(count - 1), chunks, first, last, pred};
                op.dispatch_apply(chunks);
                return op.m_result.min;
            } catch( const internal::parallelism_exception & ) {
            }
        }
    }
    return std::adjacent_find(first, last, pred);
}

template <class FwdIt>
FwdIt adjacent_find(FwdIt first, FwdIt last) noexcept
{
    return ::pstld::adjacent_find(
        first, last, [](const auto &v1, const auto &v2) { return v1 == v2; });
}

//--------------------------------------------------------------------------------------------------
// search
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2, class Pred>
struct Search : Dispatchable<Search<It1, It2, Pred>> {
    Partition<It1> m_partition;
    MinIteratorResult<It1> m_result;
    Pred m_pred;
    It2 m_first2;
    It2 m_last2;

    Search(size_t count, size_t chunks, It1 first1, It1 last1, It2 first2, It2 last2, Pred pred)
        : m_partition(first1, count, chunks), m_result{last1}, m_pred(pred), m_first2(first2),
          m_last2(last2)
    {
    }

    void run(size_t ind) noexcept
    {
        if( ind < m_result.min_chunk ) {
            for( auto p = m_partition.at(ind); p.first != p.last; ++p.first ) {
                auto i1 = p.first;
                auto i2 = m_first2;
                for( ;; ++i1, ++i2 ) {
                    if( i2 == m_last2 ) {
                        m_result.put(ind, p.first);
                        return;
                    }
                    if( !m_pred(*i1, *i2) )
                        break;
                }
            }
        }
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2, class Pred>
FwdIt1 search(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2, Pred pred) noexcept
{
    if( first1 == last1 || first2 == last2 )
        return first1;

    const auto count1 = std::distance(first1, last1);
    const auto count2 = std::distance(first2, last2);
    if( count1 < count2 )
        return last1;
    if( count1 == count2 )
        return std::equal(first1, last1, first2, last2, pred) ? first1 : last1;

    const auto count = count1 - count2 + 1;
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    try {
        internal::Search<FwdIt1, FwdIt2, Pred> op{
            static_cast<size_t>(count), chunks, first1, last1, first2, last2, pred};
        op.dispatch_apply(chunks);
        return op.m_result.min;
    } catch( const internal::parallelism_exception & ) {
    }
    return std::search(first1, last1, first2, last2, pred);
}

template <class FwdIt1, class FwdIt2>
FwdIt1 search(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2) noexcept
{
    return ::pstld::search(
        first1, last1, first2, last2, [](const auto &v1, const auto &v2) { return v1 == v2; });
}

//--------------------------------------------------------------------------------------------------
// search_n
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class T, class Pred>
struct SearchN : Dispatchable<SearchN<It, T, Pred>> {
    Partition<It> m_partition;
    MinIteratorResult<It> m_result;
    Pred m_pred;
    const T &m_val;
    size_t m_seq;

    SearchN(size_t count, size_t chunks, It first, It last, Pred pred, const T &val, size_t seq)
        : m_partition(first, count, chunks), m_result{last}, m_pred(pred), m_val(val), m_seq(seq)
    {
    }

    void run(size_t ind) noexcept
    {
        if( ind < m_result.min_chunk ) {
            for( auto p = m_partition.at(ind); p.first != p.last; ++p.first ) {
                auto it = p.first;
                for( size_t s = 0;; ++it, ++s ) {
                    if( s == m_seq ) {
                        m_result.put(ind, p.first);
                        return;
                    }
                    if( !m_pred(*it, m_val) )
                        break;
                }
            }
        }
    }
};

} // namespace internal

template <class FwdIt, class Size, class T, class Pred>
FwdIt search_n(FwdIt first, FwdIt last, Size count2, const T &value, Pred pred) noexcept
{
    if( first == last )
        return first;

    if( count2 <= Size{} )
        return first;

    const auto count1 = std::distance(first, last);
    if( static_cast<Size>(count1) < count2 )
        return last;
    if( static_cast<Size>(count1) == count2 )
        return std::all_of(first, last, [&](const auto &v) { return pred(v, value); }) ? first
                                                                                       : last;

    const auto count = count1 - count2 + 1;
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    try {
        internal::SearchN<FwdIt, T, Pred> op{static_cast<size_t>(count),
                                             chunks,
                                             first,
                                             last,
                                             pred,
                                             value,
                                             static_cast<size_t>(count2)};
        op.dispatch_apply(chunks);
        return op.m_result.min;
    } catch( const internal::parallelism_exception & ) {
    }
    return std::search_n(first, last, count2, value, pred);
}

template <class FwdIt, class Size, class T>
FwdIt search_n(FwdIt first, FwdIt last, Size count2, const T &value) noexcept
{
    return ::pstld::search_n(first, last, count2, value, std::equal_to<>{});
}

//--------------------------------------------------------------------------------------------------
// find_end
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2, class Pred>
struct FindEnd : Dispatchable<FindEnd<It1, It2, Pred>> {
    Partition<It1> m_partition;
    MaxIteratorResult<It1> m_result;
    Pred m_pred;
    It2 m_first2;
    It2 m_last2;

    FindEnd(size_t count, size_t chunks, It1 first1, It1 last1, It2 first2, It2 last2, Pred pred)
        : m_partition(first1, count, chunks), m_result{last1}, m_pred(pred), m_first2(first2),
          m_last2(last2)
    {
    }

    void run(size_t ind) noexcept
    {
        if( static_cast<ptrdiff_t>(ind) < static_cast<ptrdiff_t>(m_result.max_chunk) )
            return;

        auto p = m_partition.at(ind);
        if constexpr( is_bidirectional_iterator_v<It1> ) {
            do {
                --p.last;
                auto i1 = p.last;
                auto i2 = m_first2;
                for( ;; ++i1, ++i2 ) {
                    if( i2 == m_last2 ) {
                        m_result.put(ind, p.last);
                        return;
                    }
                    if( !m_pred(*i1, *i2) )
                        break;
                }
            } while( p.first != p.last );
        }
        else {
            auto result = p.last;
            for( ; p.first != p.last; ++p.first ) {
                auto i1 = p.first;
                auto i2 = m_first2;
                for( ;; ++i1, ++i2 ) {
                    if( i2 == m_last2 ) {
                        result = p.first;
                        break;
                    }
                    if( !m_pred(*i1, *i2) )
                        break;
                }
            }
            if( result != p.last )
                m_result.put(ind, result);
        }
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2, class Pred>
FwdIt1 find_end(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2, Pred pred) noexcept
{
    if( first1 == last1 )
        return first1;
    if( first2 == last2 )
        return last1;

    const auto count1 = std::distance(first1, last1);
    const auto count2 = std::distance(first2, last2);
    if( count1 < count2 )
        return last1;
    if( count1 == count2 )
        return std::equal(first1, last1, first2, last2, pred) ? first1 : last1;

    const auto count = count1 - count2 + 1;
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    try {
        internal::FindEnd<FwdIt1, FwdIt2, Pred> op{
            static_cast<size_t>(count), chunks, first1, last1, first2, last2, pred};
        op.dispatch_apply(chunks);
        return op.m_result.max;
    } catch( const internal::parallelism_exception & ) {
    }
    return std::find_end(first1, last1, first2, last2, pred);
}

template <class FwdIt1, class FwdIt2>
FwdIt1 find_end(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2) noexcept
{
    return ::pstld::find_end(
        first1, last1, first2, last2, [](const auto &v1, const auto &v2) { return v1 == v2; });
}

//--------------------------------------------------------------------------------------------------
// is_sorted
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Cmp>
struct IsSorted : Dispatchable<IsSorted<It, Cmp>> {
    Partition<It> m_partition;
    Cmp m_cmp;
    std::atomic_bool m_done{false};
    bool m_result = true;

    IsSorted(size_t count, size_t chunks, It first, Cmp cmp)
        : m_partition(first, count, chunks), m_cmp(cmp)
    {
    }

    void run(size_t ind) noexcept
    {
        if( m_done == false ) {
            auto p = m_partition.at(ind);
            for( auto it1 = p.first, it2 = p.first; it1 != p.last; it1 = it2 ) {
                ++it2;
                if( m_cmp(*it2, *it1) ) {
                    m_done = true;
                    m_result = false;
                    return;
                }
            }
        }
    }
};

} // namespace internal

template <class FwdIt, class Cmp>
bool is_sorted(FwdIt first, FwdIt last, Cmp cmp)
{
    const auto count = std::distance(first, last);
    if( count > 2 ) {
        const auto chunks = internal::work_chunks_min_fraction_1(count - 1);
        if( chunks > 1 ) {
            try {
                internal::IsSorted<FwdIt, Cmp> op{
                    static_cast<size_t>(count - 1), chunks, first, cmp};
                op.dispatch_apply(chunks);
                return op.m_result;
            } catch( const internal::parallelism_exception & ) {
            }
        }
    }
    return std::is_sorted(first, last, cmp);
}

template <class FwdIt>
bool is_sorted(FwdIt first, FwdIt last)
{
    return ::pstld::is_sorted(first, last, std::less<>{});
}

//--------------------------------------------------------------------------------------------------
// is_sorted_until
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Cmp>
struct IsSortedUntil : Dispatchable<IsSortedUntil<It, Cmp>> {
    Partition<It> m_partition;
    Cmp m_cmp;
    MinIteratorResult<It> m_result;

    IsSortedUntil(size_t count, size_t chunks, It first, It last, Cmp cmp)
        : m_partition(first, count, chunks), m_cmp(cmp), m_result(last)
    {
    }

    void run(size_t ind) noexcept
    {
        if( ind < m_result.min_chunk ) {
            auto p = m_partition.at(ind);
            for( auto it1 = p.first, it2 = p.first; it1 != p.last; it1 = it2 ) {
                ++it2;
                if( m_cmp(*it2, *it1) ) {
                    m_result.put(ind, it2);
                    return;
                }
            }
        }
    }
};

} // namespace internal

template <class FwdIt, class Cmp>
FwdIt is_sorted_until(FwdIt first, FwdIt last, Cmp cmp)
{
    const auto count = std::distance(first, last);
    if( count > 2 ) {
        const auto chunks = internal::work_chunks_min_fraction_1(count - 1);
        if( chunks > 1 ) {
            try {
                internal::IsSortedUntil<FwdIt, Cmp> op{
                    static_cast<size_t>(count - 1), chunks, first, last, cmp};
                op.dispatch_apply(chunks);
                return op.m_result.min;
            } catch( const internal::parallelism_exception & ) {
            }
        }
    }
    return std::is_sorted_until(first, last, cmp);
}

template <class FwdIt>
FwdIt is_sorted_until(FwdIt first, FwdIt last)
{
    return ::pstld::is_sorted_until(first, last, std::less<>{});
}

//--------------------------------------------------------------------------------------------------
// is_partitioned
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Pred>
struct IsPartitioned : Dispatchable<IsPartitioned<It, Pred>> {
    enum Scan
    {
        broken,
        all_true,
        all_false,
        true_false
    };

    Partition<It> m_partition;
    Pred m_pred;
    std::atomic<size_t> m_right_true{0};
    std::atomic<size_t> m_left_false{std::numeric_limits<size_t>::max() - 1};

    IsPartitioned(size_t count, size_t chunks, It first, Pred pred)
        : m_partition(first, count, chunks), m_pred(pred)
    {
    }

    Scan scan(It first, It last) noexcept
    {
        if( m_pred(*first) ) {
            while( true ) {
                ++first;
                if( first == last )
                    return all_true;
                if( !m_pred(*first) )
                    break;
            }
            while( true ) {
                ++first;
                if( first == last )
                    return true_false;
                if( m_pred(*first) )
                    return broken;
            }
        }
        else {
            while( true ) {
                ++first;
                if( first == last )
                    return all_false;
                if( m_pred(*first) )
                    return broken;
            }
        }
    }

    void run(size_t ind) noexcept
    {
        if( m_right_true.load() <= m_left_false.load() ) {
            auto p = m_partition.at(ind);
            auto s = scan(p.first, p.last);
            if( s == all_true ) {
                size_t was = m_right_true.load();
                while( was < ind ) {
                    if( m_right_true.compare_exchange_strong(was, ind) )
                        break;
                }
            }
            else if( s == all_false ) {
                size_t was = m_left_false.load();
                while( was > ind ) {
                    if( m_left_false.compare_exchange_strong(was, ind) )
                        break;
                }
            }
            else if( s == true_false ) {
                size_t was = m_right_true.load();
                while( was < ind ) {
                    if( m_right_true.compare_exchange_strong(was, ind) )
                        break;
                }
                was = m_left_false.load();
                while( was > ind ) {
                    if( m_left_false.compare_exchange_strong(was, ind) )
                        break;
                }
            }
            else {
                m_right_true.store(std::numeric_limits<size_t>::max());
            }
        }
    }
};

} // namespace internal

template <class FwdIt, class Pred>
bool is_partitioned(FwdIt first, FwdIt last, Pred pred)
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::IsPartitioned<FwdIt, Pred> op{
                static_cast<size_t>(count), chunks, first, pred};
            op.dispatch_apply(chunks);
            return op.m_right_true.load() <= op.m_left_false.load();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::is_partitioned(first, last, pred);
}

//--------------------------------------------------------------------------------------------------
// min_element
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Cmp>
struct MinElement : Dispatchable<MinElement<It, Cmp>> {
    Partition<It> m_partition;
    unitialized_array<It> m_results;
    Cmp m_cmp;

    MinElement(size_t count, size_t chunks, It first, Cmp cmp)
        : m_partition(first, count, chunks), m_results(chunks), m_cmp(cmp)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p = m_partition.at(ind);
        m_results.put(ind, std::min_element(p.first, p.last, m_cmp));
    }
};

template <class It, class Cmp>
iterator_value_t<It> min_iter_element(It first, It last, Cmp cmp)
{
    auto smallest = *first;
    ++first;
    for( ; first != last; ++first ) {
        if( cmp(*(*first), *smallest) ) {
            smallest = *first;
        }
    }
    return smallest;
}

} // namespace internal

template <class FwdIt, class Cmp>
FwdIt min_element(FwdIt first, FwdIt last, Cmp cmp)
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_2(count);
    if( chunks > 1 ) {
        try {
            internal::MinElement<FwdIt, Cmp> op{static_cast<size_t>(count), chunks, first, cmp};
            op.dispatch_apply(chunks);
            return internal::min_iter_element(op.m_results.begin(), op.m_results.end(), cmp);
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::min_element(first, last, cmp);
}

template <class FwdIt>
FwdIt min_element(FwdIt first, FwdIt last)
{
    return ::pstld::min_element(first, last, std::less<>{});
}

//--------------------------------------------------------------------------------------------------
// max_element
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Cmp>
struct MaxElement : Dispatchable<MaxElement<It, Cmp>> {
    Partition<It> m_partition;
    unitialized_array<It> m_results;
    Cmp m_cmp;

    MaxElement(size_t count, size_t chunks, It first, Cmp cmp)
        : m_partition(first, count, chunks), m_results(chunks), m_cmp(cmp)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p = m_partition.at(ind);
        m_results.put(ind, std::max_element(p.first, p.last, m_cmp));
    }
};

template <class It, class Cmp>
iterator_value_t<It> max_iter_element(It first, It last, Cmp cmp)
{
    auto biggest = *first;
    ++first;
    for( ; first != last; ++first ) {
        if( cmp(*biggest, *(*first)) ) {
            biggest = *first;
        }
    }
    return biggest;
}

} // namespace internal

template <class FwdIt, class Cmp>
FwdIt max_element(FwdIt first, FwdIt last, Cmp cmp)
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_2(count);
    if( chunks > 1 ) {
        try {
            internal::MaxElement<FwdIt, Cmp> op{static_cast<size_t>(count), chunks, first, cmp};
            op.dispatch_apply(chunks);
            return internal::max_iter_element(op.m_results.begin(), op.m_results.end(), cmp);
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::max_element(first, last, cmp);
}

template <class FwdIt>
FwdIt max_element(FwdIt first, FwdIt last)
{
    return ::pstld::max_element(first, last, std::less<>{});
}

//--------------------------------------------------------------------------------------------------
// minmax_element
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Cmp>
struct MinMaxElement : Dispatchable<MinMaxElement<It, Cmp>> {
    Partition<It> m_partition;
    unitialized_array<std::pair<It, It>> m_results;
    Cmp m_cmp;

    MinMaxElement(size_t count, size_t chunks, It first, Cmp cmp)
        : m_partition(first, count, chunks), m_results(chunks), m_cmp(cmp)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p = m_partition.at(ind);
        m_results.put(ind, std::minmax_element(p.first, p.last, m_cmp));
    }
};

template <class It, class Cmp>
iterator_value_t<It> minmax_iter_element(It first, It last, Cmp cmp)
{
    auto smallest = (*first).first;
    auto biggest = (*first).second;
    ++first;
    for( ; first != last; ++first ) {
        if( cmp(*((*first).first), *smallest) )
            smallest = (*first).first;
        if( !cmp(*((*first).second), *biggest) )
            biggest = (*first).second;
    }
    return {smallest, biggest};
}

} // namespace internal

template <class FwdIt, class Cmp>
std::pair<FwdIt, FwdIt> minmax_element(FwdIt first, FwdIt last, Cmp cmp)
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_2(count);
    if( chunks > 1 ) {
        try {
            internal::MinMaxElement<FwdIt, Cmp> op{static_cast<size_t>(count), chunks, first, cmp};
            op.dispatch_apply(chunks);
            return internal::minmax_iter_element(op.m_results.begin(), op.m_results.end(), cmp);
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::minmax_element(first, last, cmp);
}

template <class FwdIt>
std::pair<FwdIt, FwdIt> minmax_element(FwdIt first, FwdIt last)
{
    return ::pstld::minmax_element(first, last, std::less<>{});
}

//--------------------------------------------------------------------------------------------------
// transform
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2, class UnOp>
struct Transform2 : Dispatchable<Transform2<It1, It2, UnOp>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;
    UnOp m_op;

    Transform2(size_t count, size_t chunks, It1 first1, It2 first2, UnOp op)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks), m_op(op)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p = m_partition1.at(ind);
        std::transform(p.first, p.last, m_partition2.at(ind).first, m_op);
    }
};

template <class It1, class It2, class It3, class BinOp>
struct Transform3 : Dispatchable<Transform3<It1, It2, It3, BinOp>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;
    Partition<It3> m_partition3;
    BinOp m_op;

    Transform3(size_t count, size_t chunks, It1 first1, It2 first2, It3 first3, BinOp op)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks),
          m_partition3(first3, count, chunks), m_op(op)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p = m_partition1.at(ind);
        std::transform(
            p.first, p.last, m_partition2.at(ind).first, m_partition3.at(ind).first, m_op);
    }
};

} // namespace internal
template <class FwdIt1, class FwdIt2, class UnOp>
FwdIt2 transform(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, UnOp transform_op) noexcept
{
    const auto count = std::distance(first1, last1);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Transform2<FwdIt1, FwdIt2, UnOp> op{
                static_cast<size_t>(count), chunks, first1, first2, transform_op};
            op.dispatch_apply(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::transform(first1, last1, first2, transform_op);
}

template <class FwdIt1, class FwdIt2, class FwdIt3, class BinOp>
FwdIt3
transform(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt3 first3, BinOp transform_op) noexcept
{
    const auto count = std::distance(first1, last1);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Transform3<FwdIt1, FwdIt2, FwdIt3, BinOp> op{
                static_cast<size_t>(count), chunks, first1, first2, first3, transform_op};
            op.dispatch_apply(chunks);
            return op.m_partition3.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::transform(first1, last1, first2, first3, transform_op);
}

//--------------------------------------------------------------------------------------------------
// equal
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2, class Cmp>
struct Equal : Dispatchable<Equal<It1, It2, Cmp>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;
    Cmp m_cmp;
    std::atomic_bool m_done{false};
    bool m_result = true;

    Equal(size_t count, size_t chunks, It1 first1, It2 first2, Cmp cmp)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks), m_cmp(cmp)
    {
    }

    void run(size_t ind) noexcept
    {
        if( m_done )
            return;
        auto p1 = m_partition1.at(ind);
        auto p2 = m_partition2.at(ind);
        if( !std::equal(p1.first, p1.last, p2.first, m_cmp) ) {
            m_done = true;
            m_result = false;
        }
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2, class Cmp>
bool equal(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, Cmp cmp) noexcept
{
    const auto count = std::distance(first1, last1);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Equal<FwdIt1, FwdIt2, Cmp> op{
                static_cast<size_t>(count), chunks, first1, first2, cmp};
            op.dispatch_apply(chunks);
            return op.m_result;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::equal(first1, last1, first2, cmp);
}

template <class FwdIt1, class FwdIt2>
bool equal(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2) noexcept
{
    return ::pstld::equal(first1, last1, first2, std::equal_to<>{});
}

template <class FwdIt1, class FwdIt2, class Cmp>
bool equal(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2, Cmp cmp) noexcept
{
    const auto count = std::distance(first1, last1);
    if( count != std::distance(first2, last2) )
        return false;
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Equal<FwdIt1, FwdIt2, Cmp> op{
                static_cast<size_t>(count), chunks, first1, first2, cmp};
            op.dispatch_apply(chunks);
            return op.m_result;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::equal(first1, last1, first2, cmp);
}

template <class FwdIt1, class FwdIt2>
bool equal(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2) noexcept
{
    return ::pstld::equal(first1, last1, first2, last2, std::equal_to<>{});
}

//--------------------------------------------------------------------------------------------------
// mismatch
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2, class Cmp>
struct Mismatch : Dispatchable<Mismatch<It1, It2, Cmp>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;
    Cmp m_cmp;
    MinIteratorResult<It1> m_result1;
    MinIteratorResult<It2> m_result2;

    Mismatch(size_t count, size_t chunks, It1 first1, It2 first2, Cmp cmp)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks), m_cmp(cmp),
          m_result1(m_partition1.end()), m_result2(m_partition2.end())
    {
    }

    void run(size_t ind) noexcept
    {
        if( ind < m_result1.min_chunk ) {
            auto p1 = m_partition1.at(ind);
            auto p2 = m_partition2.at(ind);
            for( ; p1.first != p1.last; ++p1.first, ++p2.first )
                if( !m_cmp(*p1.first, *p2.first) ) {
                    m_result1.put(ind, p1.first);
                    m_result2.put(ind, p2.first);
                    return;
                }
        }
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2, class Cmp>
std::pair<FwdIt1, FwdIt2> mismatch(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, Cmp cmp) noexcept
{
    const auto count = std::distance(first1, last1);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Mismatch<FwdIt1, FwdIt2, Cmp> op{
                static_cast<size_t>(count), chunks, first1, first2, cmp};
            op.dispatch_apply(chunks);
            return {op.m_result1.min, op.m_result2.min};
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::mismatch(first1, last1, first2, cmp);
}

template <class FwdIt1, class FwdIt2>
std::pair<FwdIt1, FwdIt2> mismatch(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2) noexcept
{
    return ::pstld::mismatch(first1, last1, first2, std::equal_to<>{});
}

template <class FwdIt1, class FwdIt2, class Cmp>
std::pair<FwdIt1, FwdIt2>
mismatch(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2, Cmp cmp) noexcept
{
    const auto count = std::min(std::distance(first1, last1), std::distance(first2, last2));
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Mismatch<FwdIt1, FwdIt2, Cmp> op{
                static_cast<size_t>(count), chunks, first1, first2, cmp};
            op.dispatch_apply(chunks);
            return {op.m_result1.min, op.m_result2.min};
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::mismatch(first1, last1, first2, last2, cmp);
}

template <class FwdIt1, class FwdIt2>
std::pair<FwdIt1, FwdIt2>
mismatch(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2) noexcept
{
    return ::pstld::mismatch(first1, last1, first2, last2, std::equal_to<>{});
}

//--------------------------------------------------------------------------------------------------
// sort
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Pred>
void insertion_sort(It first, It last, Pred pred)
{
    if( first == last )
        return;
    auto it = first;
    ++it;
    for( ; it != last; ++it ) {
        auto hole = it;
        iterator_value_t<It> v = std::move(*hole);
        if( pred(v, *first) ) {
            while( true ) {
                *hole = std::move(*(hole - 1));
                --hole;
                if( hole == first )
                    break;
            }
            *first = std::move(v);
        }
        else {
            auto prev = std::prev(it);
            while( true ) {
                if( !pred(v, *prev) )
                    break;
                *hole = std::move(*prev);
                hole = prev;
                --prev;
            }
            *hole = std::move(v);
        }
    }
}

template <class It, class Pred>
void median_3(It it1, It it2, It it3, Pred pred)
{
    // orders elements at i1, it2, i3 by pred
    if( pred(*it2, *it1) )
        std::iter_swap(it1, it2);
    if( pred(*it3, *it2) ) {
        std::iter_swap(it2, it3);
        if( pred(*it2, *it1) )
            std::iter_swap(it1, it2);
    }
}

template <class It, class Pred>
void guess_median(It it1, It mid, It it2, Pred pred)
{
    const auto size = it2 - it1;
    if( size > 40 ) {
        const auto _1_8 = size / 8;
        const auto _1_4 = size / 4;
        median_3(it1, it1 + _1_8, it1 + _1_4, pred);
        median_3(mid - _1_8, mid, mid + _1_8, pred);
        median_3(it2 - _1_4, it2 - _1_8, it2, pred);
        median_3(it1 + _1_8, mid, it2 - _1_8, pred);
    }
    else {
        median_3(it1, mid, it2, pred);
    }
}

template <class It, class Pred>
std::pair<It, It> partition(It first, It last, Pred pred)
{
    auto mid = first + (last - first) / 2;
    guess_median(first, mid, std::prev(last), pred);

    auto pfirst = mid;
    auto plast = std::next(mid);

    while( first < pfirst && !pred(*(pfirst - 1), *pfirst) && !pred(*pfirst, *(pfirst - 1)) )
        --pfirst;

    while( plast < last && !pred(*plast, *pfirst) && !pred(*pfirst, *plast) )
        ++plast;

    auto gtfirst = plast;
    auto lslast = pfirst;

    while( true ) {
        for( ; gtfirst < last; ++gtfirst ) {
            if( pred(*pfirst, *gtfirst) )
                continue;
            if( pred(*gtfirst, *pfirst) )
                break;
            if( plast != gtfirst )
                std::iter_swap(plast, gtfirst);
            ++plast;
        }
        for( ; first < lslast; --lslast ) {
            if( pred(*(lslast - 1), *pfirst) )
                continue;
            if( pred(*pfirst, *(lslast - 1)) )
                break;
            if( --pfirst != lslast - 1 )
                std::iter_swap(pfirst, lslast - 1);
        }
        if( lslast == first && gtfirst == last )
            return {pfirst, plast};
        if( lslast == first ) {
            if( plast != gtfirst )
                std::iter_swap(pfirst, plast);
            ++plast;
            std::iter_swap(pfirst, gtfirst);
            ++pfirst;
            ++gtfirst;
        }
        else if( gtfirst == last ) {
            if( --lslast != --pfirst )
                std::iter_swap(lslast, pfirst);
            std::iter_swap(pfirst, --plast);
        }
        else {
            std::iter_swap(gtfirst, --lslast);
            ++gtfirst;
        }
    }
}

inline constexpr size_t log2(size_t n) noexcept
{
    size_t log2n = 0;
    while( n > 1 ) {
        log2n++;
        n >>= 1;
    }
    return log2n;
}

template <class It, class Cmp>
struct Sort {
    struct Work {
        size_t first;
        size_t last;
        size_t depth;
    };

    It m_first;
    It m_last;
    size_t m_size;
    Cmp m_cmp;
    DispatchGroup m_dg;
    size_t m_workers{max_hw_threads()};
    std::atomic<size_t> m_next_worker_index{1};
    parallelism_vector<CircularWorkStealingDeque<Work>> m_queues{m_workers};
    parallelism_vector<WorkCounter> m_work_counters{m_workers};

    Sort(It first, It last, Cmp cmp)
        : m_first(first), m_last(last), m_size(last - first), m_cmp(cmp)
    {
    }

    void start() noexcept
    {
        m_queues[0].push_bottom(Work{0, m_size, 2 * log2(m_size)});
        for( size_t i = 1; i != m_workers; ++i )
            m_dg.dispatch(static_cast<void *>(this), dispatch);
        dispatch_worker(0);
        m_dg.wait();
    }

    void dispatch_worker(size_t worker_index) noexcept
    {
        Work w;
        while( true ) {
            if( m_queues[worker_index].pop_bottom(w) ) {
                // have a local work to do
                do_sort(w, worker_index);
                continue;
            }

            for( size_t i = 1; i != m_workers; ++i ) {
                size_t steal_index = (i + worker_index) % m_workers;
                if( m_queues[steal_index].steal_top(w) ) {
                    // stolen from an other queue
                    do_sort(w, worker_index);
                    continue;
                }
            }

            // nothing to do - perhaps we are done?
            if( is_done() )
                break;

            // give up execution
            std::this_thread::yield();
        }
    }

    void do_sort(const Work w, size_t worker_index) noexcept
    {
        auto first = m_first + w.first;
        auto last = m_first + w.last;
        auto depth = w.depth;
        while( first != last ) {
            const auto len = last - first;
            if( static_cast<size_t>(len) <= insertion_sort_limit ) {
                // small len - do an insertion sort
                insertion_sort(first, last, m_cmp);
                m_work_counters[worker_index].commit_relaxed(len);
                break;
            }
            else if( depth == 0 ) {
                std::make_heap(first, last, m_cmp);
                std::sort_heap(first, last, m_cmp);
                m_work_counters[worker_index].commit_relaxed(len);
                break;
            }
            else {
                // regular len - do a quicksort
                --depth;
                auto p = internal::partition(first, last, m_cmp);
                const auto left_len = p.second - first;
                const auto mid_len = p.second - p.first;
                const auto right_len = last - p.second;
                m_work_counters[worker_index].commit_relaxed(mid_len);
                if( right_len != 0 ) {
                    if( left_len != 0 ) {
                        // fork the right unsorted side
                        fork(worker_index,
                             static_cast<size_t>(std::distance(m_first, p.second)),
                             static_cast<size_t>(std::distance(m_first, last)),
                             depth);

                        // process locally the left unsorted side
                        last = p.first;
                    }
                    else {
                        // nothing to do on the left - process the right side locally
                        first = p.second;
                    }
                }
                else {
                    // nothing to do on the right - process the left side locally
                    last = p.first;
                }
            }
        }
    }

    void fork(size_t worker_index, size_t first, size_t last, size_t depth) noexcept
    {
        try {
            m_queues[worker_index].push_bottom(Work{first, last, depth});
        } catch( const parallelism_exception & ) {
            ::std::sort(m_first + first, m_first + last, m_cmp);
            m_work_counters[worker_index].commit_relaxed(last - first);
        }
    }

    bool is_done() noexcept
    {
        size_t done = 0;
        for( size_t i = 0; i != m_workers; ++i )
            done += m_work_counters[i].load_relaxed();
        return done == m_size;
    }

    static void dispatch(void *ctx) noexcept
    {
        auto me = static_cast<Sort *>(ctx);
        size_t index = me->m_next_worker_index++;
        me->dispatch_worker(index);
    }
};

} // namespace internal

template <class RanIt, class Cmp>
void sort(RanIt first, RanIt last, Cmp cmp) noexcept
{
    const auto count = std::distance(first, last);
    if( static_cast<size_t>(count) > internal::insertion_sort_limit ) {
        try {
            internal::Sort<RanIt, Cmp> sort(first, last, cmp);
            sort.start();
            return;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    std::sort(first, last, cmp);
}

template <class RanIt>
void sort(RanIt first, RanIt last) noexcept
{
    return ::pstld::sort(first, last, std::less<>{});
}

//--------------------------------------------------------------------------------------------------
// stable_sort
//--------------------------------------------------------------------------------------------------

namespace internal {

inline size_t stable_sort_tree_height(size_t elems) noexcept
{
    size_t chunks_elems = elems / insertion_sort_limit;
    size_t log2_elems = log2(chunks_elems);

    size_t chunks_oversubscr = max_hw_threads() * chunks_per_cpu;
    size_t log2_oversubscr = log2(chunks_oversubscr);

    return std::min(log2_elems, log2_oversubscr) & ~size_t(1);
}

template <class It1, class It2, class Cmp>
void merge_mid_move(It1 first, It1 mid, It1 last, It2 out, Cmp cmp)
{
    // TODO: should it move-construct in-place instead of moving into?
    auto first1 = first;
    auto first2 = mid;
    for( ; first1 != mid; ++out ) {
        if( first2 == last ) {
            std::move(first1, mid, out);
            return;
        }
        if( cmp(*first2, *first1) ) {
            *out = std::move(*first2);
            ++first2;
        }
        else {
            *out = std::move(*first1);
            ++first1;
        }
    }
    std::move(first2, last, out);
}

template <class It, class Cmp>
void insertion_sort_buf_assign_move(It first, It last, Cmp cmp, iterator_value_t<It> *buf)
{
    if( first == last )
        return;

    auto last2 = buf;
    *(last2++) = std::move(*first);

    for( ; ++first != last; ++last2 ) {
        auto j2 = last2;
        auto i2 = j2;
        if( cmp(*first, *--i2) ) {
            *j2 = std::move(*i2);
            for( --j2; i2 != buf && cmp(*first, *--i2); --j2 )
                *j2 = std::move(*i2);
            *j2 = std::move(*first);
        }
        else {
            *j2 = std::move(*first);
        }
    }
}

template <class It, class Cmp>
void stable_sort(It first, It last, Cmp cmp, iterator_value_t<It> *buf);

template <class It, class Cmp>
void stable_sort_buf_assign_move(It first, It last, Cmp cmp, iterator_value_t<It> *buf)
{
    size_t len = last - first;
    if( len == 0 ) {
    }
    else if( len == 1 ) {
        *buf = std::move(*first);
    }
    else if( len == 2 ) {
        auto second = first;
        ++second;
        if( cmp(*second, *first) ) {
            *(buf++) = std::move(*second);
            *buf = std::move(*first);
        }
        else {
            *(buf++) = std::move(*first);
            *buf = std::move(*second);
        }
    }
    else if( len <= insertion_sort_limit ) {
        insertion_sort_buf_assign_move(first, last, cmp, buf);
    }
    else {
        size_t half = len / 2;
        It mid = first + half;
        stable_sort(first, mid, cmp, buf);
        stable_sort(mid, last, cmp, buf + half);
        merge_mid_move(first, mid, last, buf, cmp);
    }
}

template <class It, class Cmp>
void stable_sort(It first, It last, Cmp cmp, iterator_value_t<It> *buf)
{
    size_t len = last - first;
    if( len <= insertion_sort_limit ) {
        insertion_sort(first, last, cmp);
    }
    else {
        size_t half = len / 2;
        It mid = first + half;
        stable_sort_buf_assign_move(first, mid, cmp, buf);
        stable_sort_buf_assign_move(mid, last, cmp, buf + half);
        merge_mid_move(buf, buf + half, buf + len, first, cmp);
    }
}

template <class It, class Cmp>
struct StableSort {
    struct Work {
        size_t first;
        size_t last;
        size_t depth;
    };

    It m_first;
    It m_last;
    Cmp m_cmp;
    size_t m_size;
    size_t m_height;
    size_t m_chunks;
    size_t m_workers{max_hw_threads()};
    std::atomic<size_t> m_next_chunk{0};

    Partition<It> m_partition;
    parallelism_vector<iterator_value_t<It>> m_buf; // TODO: should be raw temp memory instead?
    parallelism_vector<std::atomic<bool>> m_flags;

    DispatchGroup m_dg;

    StableSort(It first, It last, Cmp cmp)
        : m_first(first), m_last(last), m_cmp(cmp), m_size(last - first),
          m_height(stable_sort_tree_height(m_size)), m_chunks(size_t(1) << m_height),
          m_partition(first, m_size, m_chunks), m_buf(m_size), m_flags(size_t(1) << m_height)
    {
    }

    void start() noexcept
    {
        for( size_t i = 1; i != m_workers; ++i )
            m_dg.dispatch(static_cast<void *>(this), dispatch);
        dispatch_worker();
        m_dg.wait();
    }

    static void dispatch(void *ctx) noexcept
    {
        auto me = static_cast<StableSort *>(ctx);
        me->dispatch_worker();
    }

    void dispatch_worker() noexcept
    {
        while( true ) {
            size_t chunk = m_next_chunk.fetch_add(1);
            if( chunk >= m_chunks )
                break;
            bottomup(chunk);
        }
    }

    void bottomup(size_t ind) noexcept
    {
        auto p = m_partition.at(ind);

        stable_sort(p.first, p.last, m_cmp, m_buf.data() + std::distance(m_first, p.first));
        std::atomic<bool> *flag_ptr = m_flags.data();
        if( !flag_ptr[ind / 2].exchange(true) ) // try to give up merging
            return;

        auto buf = m_buf.data();
        for( size_t lvl = 1, chunks = m_chunks / 2;; ++lvl, chunks >>= 1 ) {
            bool odd = ind & 1;
            ind >>= 1;

            auto first = odd ? m_partition.at(ind << lvl).first : p.first;
            auto mid = odd ? p.first : p.last;
            auto last = odd ? p.last : m_partition.at(((ind + 1) << lvl) - 1).last;

            if( lvl % 2 ) {
                // merge into tmp buf
                merge_mid_move(first, mid, last, buf + (first - m_first), m_cmp);
            }
            else {
                // merge back into orig buffer
                merge_mid_move(buf + (first - m_first),
                               buf + (mid - m_first),
                               buf + (last - m_first),
                               first,
                               m_cmp);
            }

            flag_ptr += chunks;
            if( !flag_ptr[ind / 2].exchange(true) ) // try to give up merging
                return;

            p.first = first;
            p.last = last;
        }
    }
};

} // namespace internal

template <class RanIt, class Cmp>
void stable_sort(RanIt first, RanIt last, Cmp cmp) noexcept
{
    const auto count = std::distance(first, last);
    if( static_cast<size_t>(count) > internal::insertion_sort_limit * 4 ) {
        try {
            internal::StableSort<RanIt, Cmp> op(first, last, cmp);
            op.start();
            return;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    std::stable_sort(first, last, cmp);
}

template <class RanIt>
void stable_sort(RanIt first, RanIt last) noexcept
{
    return ::pstld::stable_sort(first, last, std::less<>{});
}

//--------------------------------------------------------------------------------------------------
// merge
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2, class It3, class Cmp>
struct Merge {
    struct Work {
        size_t first1;
        size_t last1;
        size_t first2;
        size_t last2;
        size_t first3;
    };

    It1 m_first1;
    It1 m_last1;
    size_t m_size1;
    It2 m_first2;
    It2 m_last2;
    size_t m_size2;
    It3 m_first3;
    It3 m_last3;
    size_t m_size3; // = m_size1 + m_size2
    Cmp m_cmp;
    DispatchGroup m_dg;
    size_t m_workers{max_hw_threads()};
    std::atomic<size_t> m_next_worker_index{1};
    parallelism_vector<CircularWorkStealingDeque<Work>> m_queues{m_workers};
    parallelism_vector<WorkCounter> m_work_counters{m_workers};

    Merge(It1 first1, It1 last1, It2 first2, It2 last2, It3 first3, Cmp cmp)
        : m_first1(first1), m_last1(last1), m_size1(last1 - first1), m_first2(first2),
          m_last2(last2), m_size2(last2 - first2), m_first3(first3),
          m_last3(std::next(first3, m_size1 + m_size2)), m_size3(m_size1 + m_size2), m_cmp(cmp)
    {
    }

    void start() noexcept
    {
        m_queues[0].push_bottom(Work{0, m_size1, 0, m_size2, 0});
        for( size_t i = 1; i != m_workers; ++i )
            m_dg.dispatch(static_cast<void *>(this), dispatch);
        dispatch_worker(0);
        m_dg.wait();
    }

    void dispatch_worker(size_t worker_index) noexcept
    {
        Work w;
        while( true ) {
            if( m_queues[worker_index].pop_bottom(w) ) {
                // have a local work to do
                do_merge(w, worker_index);
                continue;
            }

            for( size_t i = 1; i != m_workers; ++i ) {
                size_t steal_index = (i + worker_index) % m_workers;
                if( m_queues[steal_index].steal_top(w) ) {
                    // stolen from an other queue
                    do_merge(w, worker_index);
                    continue;
                }
            }

            // nothing to do - perhaps we are done?
            if( is_done() )
                break;

            // give up execution
            std::this_thread::yield();
        }
    }

    void do_merge(const Work w, size_t worker_index) noexcept
    {
        size_t first1 = w.first1;
        size_t last1 = w.last1;
        size_t first2 = w.first2;
        size_t last2 = w.last2;
        size_t first3 = w.first3;

        while( (last1 - first1) + (last2 - first2) > merge_parallel_limit ) {
            // chop the input in roughly halves while it's big enough
            size_t mid1;
            size_t mid2;
            if( last1 - first1 < last2 - first2 ) {
                mid2 = first2 + (last2 - first2) / 2;
                mid1 = std::distance(
                    m_first1,
                    std::lower_bound(
                        m_first1 + first1, m_first1 + last1, *(m_first2 + mid2), m_cmp));
            }
            else {
                mid1 = first1 + (last1 - first1) / 2;
                mid2 = std::distance(
                    m_first2,
                    std::lower_bound(
                        m_first2 + first2, m_first2 + last2, *(m_first1 + mid1), m_cmp));
            }

            fork(
                worker_index, mid1, last1, mid2, last2, first3 + (mid1 - first1) + (mid2 - first2));
            last1 = mid1;
            last2 = mid2;
        }

        std::merge(m_first1 + first1,
                   m_first1 + last1,
                   m_first2 + first2,
                   m_first2 + last2,
                   m_first3 + first3,
                   m_cmp);
        m_work_counters[worker_index].commit_relaxed((last1 - first1) + (last2 - first2));
    }

    void fork(size_t worker_index,
              size_t first1,
              size_t last1,
              size_t first2,
              size_t last2,
              size_t first3) noexcept
    {
        try {
            m_queues[worker_index].push_bottom(Work{first1, last1, first2, last2, first3});
        } catch( const parallelism_exception & ) {
            std::merge(m_first1 + first1,
                       m_first1 + last1,
                       m_first2 + first2,
                       m_first2 + last2,
                       m_first3 + first3,
                       m_cmp);
            m_work_counters[worker_index].commit_relaxed((last1 - first1) + (last2 - first2));
        }
    }

    bool is_done() noexcept
    {
        size_t done = 0;
        for( size_t i = 0; i != m_workers; ++i )
            done += m_work_counters[i].load_relaxed();
        return done == m_size3;
    }

    static void dispatch(void *ctx) noexcept
    {
        auto me = static_cast<Merge *>(ctx);
        size_t index = me->m_next_worker_index++;
        me->dispatch_worker(index);
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2, class FwdIt3, class Cmp>
FwdIt3
merge(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2, FwdIt3 first3, Cmp cmp) noexcept
{
    if constexpr( internal::is_random_iterator_v<FwdIt1> &&
                  internal::is_random_iterator_v<FwdIt2> &&
                  internal::is_random_iterator_v<FwdIt3> ) {
        const auto count = std::distance(first1, last1) + std::distance(first2, last2);
        if( static_cast<size_t>(count) > internal::merge_parallel_limit ) {
            try {
                internal::Merge<FwdIt1, FwdIt2, FwdIt3, Cmp> merge(
                    first1, last1, first2, last2, first3, cmp);
                merge.start();
                return merge.m_last3;
            } catch( const internal::parallelism_exception & ) {
            }
        }
    }
    return std::merge(first1, last1, first2, last2, first3, cmp);
}

template <class FwdIt1, class FwdIt2, class FwdIt3>
FwdIt3 merge(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2, FwdIt3 first3) noexcept
{
    return ::pstld::merge(first1, last1, first2, last2, first3, std::less<>{});
}

//--------------------------------------------------------------------------------------------------
// fill, fill_n
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class T>
struct Fill : Dispatchable<Fill<It, T>> {
    Partition<It> m_partition;
    const T &m_val;

    Fill(size_t count, size_t chunks, It first, const T &val)
        : m_partition(first, count, chunks), m_val(val)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p = m_partition.at(ind);
        std::fill(p.first, p.last, m_val);
    }
};

} // namespace internal

template <class FwdIt, class T>
void fill(FwdIt first, FwdIt last, const T &val) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Fill<FwdIt, T> op{static_cast<size_t>(count), chunks, first, val};
            op.dispatch_apply(chunks);
            return;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::fill(first, last, val);
}

template <class FwdIt, class Size, class T>
FwdIt fill_n(FwdIt first, Size count, const T &val) noexcept
{
    if( count < 1 )
        return first;

    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Fill<FwdIt, T> op{static_cast<size_t>(count), chunks, first, val};
            op.dispatch_apply(chunks);
            return op.m_partition.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::fill_n(first, count, val);
}

//--------------------------------------------------------------------------------------------------
// generate, generate_n
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class Gen>
struct Generate : Dispatchable<Generate<It, Gen>> {
    Partition<It> m_partition;
    Gen &m_gen;

    Generate(size_t count, size_t chunks, It first, Gen &gen)
        : m_partition(first, count, chunks), m_gen(gen)
    {
    }

    void run(size_t ind) noexcept
    {
        // this technically violates the assumption that the generation will be performed in a
        // deterministic order, but that in turn essentially makes a parallel version
        // unimplementable. so instead this implementation calls the generator concurrently without
        // a specific order.
        for( auto p = m_partition.at(ind); p.first != p.last; ++p.first )
            *p.first = m_gen();
    }
};

} // namespace internal

template <class FwdIt, class Gen>
void generate(FwdIt first, FwdIt last, Gen gen) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Generate<FwdIt, Gen> op{static_cast<size_t>(count), chunks, first, gen};
            op.dispatch_apply(chunks);
            return;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::generate(first, last, gen);
}

template <class FwdIt, class Size, class Gen>
FwdIt generate_n(FwdIt first, Size count, Gen gen) noexcept
{
    if( count < 1 )
        return first;

    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Generate<FwdIt, Gen> op{static_cast<size_t>(count), chunks, first, gen};
            op.dispatch_apply(chunks);
            return op.m_partition.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::generate_n(first, count, gen);
}

//--------------------------------------------------------------------------------------------------
// copy, copy_n
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2>
struct Copy : Dispatchable<Copy<It1, It2>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;

    Copy(size_t count, size_t chunks, It1 first1, It2 first2)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p1 = m_partition1.at(ind);
        auto p2 = m_partition2.at(ind);
        std::copy(p1.first, p1.last, p2.first);
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2>
FwdIt2 copy(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2) noexcept
{
    const auto count = std::distance(first1, last1);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Copy<FwdIt1, FwdIt2> op{static_cast<size_t>(count), chunks, first1, first2};
            op.dispatch_apply(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::copy(first1, last1, first2);
}

template <class FwdIt1, class Size, class FwdIt2>
FwdIt2 copy_n(FwdIt1 first1, Size count, FwdIt2 first2) noexcept
{
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Copy<FwdIt1, FwdIt2> op{static_cast<size_t>(count), chunks, first1, first2};
            op.dispatch_apply(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::copy_n(first1, count, first2);
}

//--------------------------------------------------------------------------------------------------
// replace, replace_if
//--------------------------------------------------------------------------------------------------

template <class FwdIt, class T>
void replace(FwdIt first, FwdIt last, const T &old_val, const T &new_val) noexcept
{
    ::pstld::for_each(first, last, [&](auto &val) {
        if( val == old_val )
            val = new_val;
    });
}

template <class FwdIt, class Pred, class T>
void replace_if(FwdIt first, FwdIt last, Pred pred, const T &new_val) noexcept
{
    ::pstld::for_each(first, last, [&, pred](auto &val) mutable {
        if( pred(val) )
            val = new_val;
    });
}

//--------------------------------------------------------------------------------------------------
// swap_ranges
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2>
struct SwapRanges : Dispatchable<SwapRanges<It1, It2>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;

    SwapRanges(size_t count, size_t chunks, It1 first1, It2 first2)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p1 = m_partition1.at(ind);
        auto p2 = m_partition2.at(ind);
        std::swap_ranges(p1.first, p1.last, p2.first);
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2>
FwdIt2 swap_ranges(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2) noexcept
{
    const auto count = std::distance(first1, last1);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::SwapRanges<FwdIt1, FwdIt2> op{
                static_cast<size_t>(count), chunks, first1, first2};
            op.dispatch_apply(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::swap_ranges(first1, last1, first2);
}

//--------------------------------------------------------------------------------------------------
// adjacent_difference
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2, class BinOp>
struct AdjacentDifference : Dispatchable<AdjacentDifference<It1, It2, BinOp>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;
    BinOp m_op;

    AdjacentDifference(size_t count, size_t chunks, It1 first1, It2 first2, BinOp op)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks), m_op(op)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p1 = m_partition1.at(ind);
        auto p2 = m_partition2.at(ind);
        auto i1 = p1.first;
        auto i2 = std::next(p1.first);
        while( true ) {
            *p2.first = m_op(*i2, *i1);
            if( i2 == p1.last )
                break;
            i1 = i2;
            ++i2;
            ++p2.first;
        }
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2, class BinOp>
FwdIt2 adjacent_difference(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, BinOp bop) noexcept
{
    const auto count = std::distance(first1, last1);
    if( count > 2 ) {
        *first2 = *first1;
        const auto chunks = internal::work_chunks_min_fraction_1(count - 1);
        try {
            internal::AdjacentDifference<FwdIt1, FwdIt2, BinOp> op{
                static_cast<size_t>(count - 1), chunks, first1, std::next(first2), bop};
            op.dispatch_apply(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return ::std::adjacent_difference(first1, last1, first2, bop);
}

template <class FwdIt1, class FwdIt2>
FwdIt2 adjacent_difference(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2) noexcept
{
    return ::pstld::adjacent_difference(first1, last1, first2, std::minus<>{});
}

//--------------------------------------------------------------------------------------------------
// reverse
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It>
struct Reverse : Dispatchable<Reverse<It>> {
    Partition<It> m_partition1;
    Partition<It, false> m_partition2;

    Reverse(size_t count, size_t chunks, It first, It last)
        : m_partition1(first, count, chunks), m_partition2(std::prev(last), count, chunks)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p1 = m_partition1.at(ind);
        auto p2 = m_partition2.at(ind);
        for( ; p1.first != p1.last; ++p1.first, --p2.first )
            std::iter_swap(p1.first, p2.first);
    }
};

} // namespace internal

template <class FwdIt>
void reverse(FwdIt first, FwdIt last) noexcept
{
    const auto count = std::distance(first, last);
    if( count > 3 ) {
        const auto chunks = internal::work_chunks_min_fraction_1(count / 2);
        try {
            internal::Reverse<FwdIt> op{static_cast<size_t>(count / 2), chunks, first, last};
            op.dispatch_apply(chunks);
            return;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    ::std::reverse(first, last);
}

//--------------------------------------------------------------------------------------------------
// inclusive_scan, transform_inclusive_scan
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class BinOp, class UnOp, class R>
R partial_reduce(It first, It last, BinOp reduce, UnOp transform)
{
    auto init = first++;
    auto val = static_cast<R>(reduce(transform(*init), transform(*first++)));
    for( ; first != last; ++first )
        val = reduce(std::move(val), transform(*first));
    return val;
}

template <class It1, class It2, class BinOp, class UnOp, class T>
struct InclusiveScan : Dispatchable2<InclusiveScan<It1, It2, BinOp, UnOp, T>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;
    unitialized_array<T> m_reduced;
    BinOp m_op;
    UnOp m_tr;
    T &m_init;

    InclusiveScan(size_t count, size_t chunks, It1 first1, It2 first2, BinOp op, UnOp tr, T &init)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks),
          m_reduced(chunks), m_op(op), m_tr(tr), m_init(init)
    {
    }

    void run_first(size_t ind) noexcept
    {
        // fill the reduced chunks
        auto p1 = m_partition1.at(ind);
        m_reduced.put(ind, partial_reduce<It1, BinOp, UnOp, T>(p1.first, p1.last, m_op, m_tr));
    }

    void run_second(size_t ind) noexcept
    {
        // fill the output
        auto p1 = m_partition1.at(ind);
        auto p2 = m_partition2.at(ind);
        auto val = ind == 0
                       ? static_cast<T>(m_op(m_init, m_tr(*p1.first++)))
                       : static_cast<T>(m_op(std::move(m_reduced[ind - 1]), m_tr(*p1.first++)));
        *p2.first++ = val;
        for( ; p1.first != p1.last; ++p1.first, ++p2.first ) {
            val = m_op(std::move(val), m_tr(*p1.first));
            *p2.first = val;
        }
    }

    void accumulate() noexcept
    {
        // reduce chunks serially
        auto first = m_reduced.begin();
        auto last = m_reduced.end();
        *first = m_op(m_init, std::move(*first));
        for( auto prev = first++; first != last; ++first, ++prev )
            *first = m_op(*prev, std::move(*first));
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2, class BinOp, class UnOp, class T>
FwdIt2 transform_inclusive_scan(FwdIt1 first1,
                                FwdIt1 last1,
                                FwdIt2 first2,
                                BinOp reduce_op,
                                UnOp transform_op,
                                T val) noexcept
{
    const auto count = std::distance(first1, last1);
    const auto chunks = internal::work_chunks_min_fraction_2(count);
    if( chunks > 1 ) {
        try {
            internal::InclusiveScan<FwdIt1, FwdIt2, BinOp, UnOp, T> op{
                static_cast<size_t>(count), chunks, first1, first2, reduce_op, transform_op, val};
            op.dispatch_apply_first(chunks);
            op.accumulate();
            op.dispatch_apply_second(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return ::std::transform_inclusive_scan(
        first1, last1, first2, reduce_op, transform_op, std::move(val));
}

template <class FwdIt1, class FwdIt2, class BinOp, class UnOp>
FwdIt2 transform_inclusive_scan(FwdIt1 first1,
                                FwdIt1 last1,
                                FwdIt2 first2,
                                BinOp reduce_op,
                                UnOp transform_op) noexcept
{
    const auto count = std::distance(first1, last1);
    if( count == 0 )
        return first2;
    const auto chunks = internal::work_chunks_min_fraction_2(count - 1);
    if( chunks > 1 ) {
        try {
            *first2 = transform_op(*first1);
            internal::InclusiveScan<FwdIt1, FwdIt2, BinOp, UnOp, internal::iterator_value_t<FwdIt2>>
                op{static_cast<size_t>(count - 1),
                   chunks,
                   std::next(first1),
                   std::next(first2),
                   reduce_op,
                   transform_op,
                   *first2};
            op.dispatch_apply_first(chunks);
            op.accumulate();
            op.dispatch_apply_second(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return ::std::transform_inclusive_scan(first1, last1, first2, reduce_op, transform_op);
}

template <class FwdIt1, class FwdIt2, class BinOp, class T>
FwdIt2 inclusive_scan(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, BinOp reduce_op, T val) noexcept
{
    return ::pstld::transform_inclusive_scan(
        first1, last1, first2, reduce_op, internal::no_op{}, std::move(val));
}

template <class FwdIt1, class FwdIt2, class BinOp>
FwdIt2 inclusive_scan(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, BinOp reduce_op) noexcept
{
    return ::pstld::transform_inclusive_scan(first1, last1, first2, reduce_op, internal::no_op{});
}

template <class FwdIt1, class FwdIt2>
FwdIt2 inclusive_scan(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2) noexcept
{
    return ::pstld::inclusive_scan(first1, last1, first2, ::std::plus<>{});
}

//--------------------------------------------------------------------------------------------------
// exclusive_scan, transform_exclusive_scan
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2, class BinOp, class UnOp, class T>
struct ExclusiveScan : Dispatchable2<ExclusiveScan<It1, It2, BinOp, UnOp, T>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;
    unitialized_array<T> m_reduced;
    BinOp m_op;
    UnOp m_tr;
    T &m_init;

    ExclusiveScan(size_t count, size_t chunks, It1 first1, It2 first2, BinOp op, UnOp tr, T &init)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks),
          m_reduced(chunks), m_op(op), m_tr(tr), m_init(init)
    {
    }

    void run_first(size_t ind) noexcept
    {
        // fill the reduced chunks
        auto p1 = m_partition1.at(ind);
        m_reduced.put(ind, partial_reduce<It1, BinOp, UnOp, T>(p1.first, p1.last, m_op, m_tr));
    }

    void run_second(size_t ind) noexcept
    {
        // fill the output
        auto p1 = m_partition1.at(ind);
        auto p2 = m_partition2.at(ind);
        auto val = std::move(ind == 0 ? m_init : m_reduced[ind - 1]);
        for( ; p1.first != p1.last; ++p1.first, ++p2.first ) {
            auto next = m_op(val, m_tr(*p1.first));
            *p2.first = std::move(val);
            val = std::move(next);
        }
    }

    void accumulate() noexcept
    {
        // reduce chunks serially
        auto first = m_reduced.begin();
        auto last = m_reduced.end();
        *first = m_op(m_init, std::move(*first));
        for( auto prev = first++; first != last; ++first, ++prev )
            *first = m_op(*prev, std::move(*first));
    }
};

template <class FwdIt1, class FwdIt2, class T, class BinOp, class UnOp>
FwdIt2 transform_exclusive_scan_serial(FwdIt1 first1,
                                       FwdIt1 last1,
                                       FwdIt2 first2,
                                       T val,
                                       BinOp reduce_op,
                                       UnOp transform_op) noexcept
{
    // manual serial implementation because transform_exclusive_scan from libc++ doesn't play well
    // with MSVC's unit tests
    for( ; first1 != last1; ++first1, ++first2 ) {
        auto next = reduce_op(val, transform_op(*first1));
        *first2 = std::move(val);
        val = std::move(next);
    }
    return first2;
}

} // namespace internal

template <class FwdIt1, class FwdIt2, class T, class BinOp, class UnOp>
FwdIt2 transform_exclusive_scan(FwdIt1 first1,
                                FwdIt1 last1,
                                FwdIt2 first2,
                                T val,
                                BinOp reduce_op,
                                UnOp transform_op) noexcept
{
    const auto count = std::distance(first1, last1);
    if( count == 0 )
        return first2;
    if( count == 1 ) {
        *first2 = std::move(val);
        return std::next(first2);
    }
    const auto chunks = internal::work_chunks_min_fraction_2(count);
    if( chunks > 1 ) {
        try {
            internal::ExclusiveScan<FwdIt1, FwdIt2, BinOp, UnOp, T> op{
                static_cast<size_t>(count), chunks, first1, first2, reduce_op, transform_op, val};
            op.dispatch_apply_first(chunks);
            op.accumulate();
            op.dispatch_apply_second(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return internal::transform_exclusive_scan_serial(
        first1, last1, first2, std::move(val), reduce_op, transform_op);
}

template <class FwdIt1, class FwdIt2, class T, class BinOp>
FwdIt2 exclusive_scan(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, T val, BinOp reduce_op) noexcept
{
    return ::pstld::transform_exclusive_scan(
        first1, last1, first2, std::move(val), reduce_op, internal::no_op{});
}

template <class FwdIt1, class FwdIt2, class T>
FwdIt2 exclusive_scan(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, T val) noexcept
{
    return ::pstld::exclusive_scan(first1, last1, first2, std::move(val), ::std::plus<>{});
}

//--------------------------------------------------------------------------------------------------
// lexicographical_compare
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2, class Cmp>
struct LexicographicalCompare : Dispatchable<LexicographicalCompare<It1, It2, Cmp>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;
    Cmp m_cmp;
    MinIteratorResult<It1> m_result1;
    MinIteratorResult<It2> m_result2;

    LexicographicalCompare(size_t count, size_t chunks, It1 first1, It2 first2, Cmp cmp)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks), m_cmp(cmp),
          m_result1(m_partition1.end()), m_result2(m_partition2.end())
    {
    }

    void run(size_t ind) noexcept
    {
        if( ind < m_result1.min_chunk ) {
            auto p1 = m_partition1.at(ind);
            auto p2 = m_partition2.at(ind);
            for( ; p1.first != p1.last; ++p1.first, ++p2.first ) {
                if( m_cmp(*p1.first, *p2.first) || m_cmp(*p2.first, *p1.first) ) {
                    m_result1.put(ind, p1.first);
                    m_result2.put(ind, p2.first);
                    return;
                }
            }
        }
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2, class Cmp>
bool lexicographical_compare(FwdIt1 first1,
                             FwdIt1 last1,
                             FwdIt2 first2,
                             FwdIt2 last2,
                             Cmp cmp) noexcept
{
    const auto count1 = std::distance(first1, last1);
    const auto count2 = std::distance(first2, last2);
    const auto count_min = std::min(count1, count2);
    const auto chunks = internal::work_chunks_min_fraction_1(count_min);
    if( chunks > 1 ) {
        try {
            internal::LexicographicalCompare<FwdIt1, FwdIt2, Cmp> op{
                static_cast<size_t>(count_min), chunks, first1, first2, cmp};
            op.dispatch_apply(chunks);
            if( static_cast<FwdIt1>(op.m_result1.min) != op.m_partition1.end() )
                return cmp(*static_cast<FwdIt1>(op.m_result1.min),
                           *static_cast<FwdIt2>(op.m_result2.min));
            else
                return count1 < count2;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return ::std::lexicographical_compare(first1, last1, first2, last2, cmp);
}

template <class FwdIt1, class FwdIt2>
bool lexicographical_compare(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2, FwdIt2 last2) noexcept
{
    return ::pstld::lexicographical_compare(first1, last1, first2, last2, std::less<>{});
}

//--------------------------------------------------------------------------------------------------
// uninitialized_construct
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, bool Value>
struct UninitializedConstruct : Dispatchable<UninitializedConstruct<It, Value>> {
    Partition<It> m_partition;

    UninitializedConstruct(size_t count, size_t chunks, It first)
        : m_partition(first, count, chunks)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p = m_partition.at(ind);
        if constexpr( Value )
            std::uninitialized_value_construct(p.first, p.last);
        else
            std::uninitialized_default_construct(p.first, p.last);
    }
};

} // namespace internal

template <class FwdIt>
void uninitialized_default_construct(FwdIt first, FwdIt last) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::UninitializedConstruct<FwdIt, false> op{
                static_cast<size_t>(count), chunks, first};
            op.dispatch_apply(chunks);
            return;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::uninitialized_default_construct(first, last);
}

template <class FwdIt, class Size>
FwdIt uninitialized_default_construct_n(FwdIt first, Size count) noexcept
{
    if( count < 1 )
        return first;

    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::UninitializedConstruct<FwdIt, false> op{
                static_cast<size_t>(count), chunks, first};
            op.dispatch_apply(chunks);
            return op.m_partition.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::uninitialized_default_construct_n(first, count);
}

template <class FwdIt>
void uninitialized_value_construct(FwdIt first, FwdIt last) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::UninitializedConstruct<FwdIt, true> op{
                static_cast<size_t>(count), chunks, first};
            op.dispatch_apply(chunks);
            return;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::uninitialized_value_construct(first, last);
}

template <class FwdIt, class Size>
FwdIt uninitialized_value_construct_n(FwdIt first, Size count) noexcept
{
    if( count < 1 )
        return first;

    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::UninitializedConstruct<FwdIt, true> op{
                static_cast<size_t>(count), chunks, first};
            op.dispatch_apply(chunks);
            return op.m_partition.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::uninitialized_value_construct_n(first, count);
}

//--------------------------------------------------------------------------------------------------
// uninitialized_copy, uninitialized_move
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2, bool Copy>
struct UninitializedCopyMove : Dispatchable<UninitializedCopyMove<It1, It2, Copy>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;

    UninitializedCopyMove(size_t count, size_t chunks, It1 first1, It2 first2)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p1 = m_partition1.at(ind);
        auto p2 = m_partition2.at(ind);
        if constexpr( Copy )
            std::uninitialized_copy(p1.first, p1.last, p2.first);
        else
            std::uninitialized_move(p1.first, p1.last, p2.first);
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2>
FwdIt2 uninitialized_copy(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2) noexcept
{
    const auto count = std::distance(first1, last1);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::UninitializedCopyMove<FwdIt1, FwdIt2, true> op{
                static_cast<size_t>(count), chunks, first1, first2};
            op.dispatch_apply(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::uninitialized_copy(first1, last1, first2);
}

template <class FwdIt1, class Size, class FwdIt2>
FwdIt2 uninitialized_copy_n(FwdIt1 first1, Size count, FwdIt2 first2) noexcept
{
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::UninitializedCopyMove<FwdIt1, FwdIt2, true> op{
                static_cast<size_t>(count), chunks, first1, first2};
            op.dispatch_apply(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::uninitialized_copy_n(first1, count, first2);
}

template <class FwdIt1, class FwdIt2>
FwdIt2 uninitialized_move(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2) noexcept
{
    const auto count = std::distance(first1, last1);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::UninitializedCopyMove<FwdIt1, FwdIt2, false> op{
                static_cast<size_t>(count), chunks, first1, first2};
            op.dispatch_apply(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::uninitialized_move(first1, last1, first2);
}

template <class FwdIt1, class Size, class FwdIt2>
std::pair<FwdIt1, FwdIt2> uninitialized_move_n(FwdIt1 first1, Size count, FwdIt2 first2) noexcept
{
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::UninitializedCopyMove<FwdIt1, FwdIt2, false> op{
                static_cast<size_t>(count), chunks, first1, first2};
            op.dispatch_apply(chunks);
            return {op.m_partition1.end(), op.m_partition2.end()};
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::uninitialized_move_n(first1, count, first2);
}

//--------------------------------------------------------------------------------------------------
// uninitialized_fill
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It, class T>
struct UninitializedFill : Dispatchable<UninitializedFill<It, T>> {
    Partition<It> m_partition;
    const T &m_val;

    UninitializedFill(size_t count, size_t chunks, It first, const T &val)
        : m_partition(first, count, chunks), m_val(val)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p = m_partition.at(ind);
        std::uninitialized_fill(p.first, p.last, m_val);
    }
};

} // namespace internal

template <class FwdIt, class T>
void uninitialized_fill(FwdIt first, FwdIt last, const T &val) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::UninitializedFill<FwdIt, T> op{
                static_cast<size_t>(count), chunks, first, val};
            op.dispatch_apply(chunks);
            return;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::uninitialized_fill(first, last, val);
}

template <class FwdIt, class Size, class T>
FwdIt uninitialized_fill_n(FwdIt first, Size count, const T &val) noexcept
{
    if( count < 1 )
        return first;

    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::UninitializedFill<FwdIt, T> op{
                static_cast<size_t>(count), chunks, first, val};
            op.dispatch_apply(chunks);
            return op.m_partition.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::uninitialized_fill_n(first, count, val);
}

//--------------------------------------------------------------------------------------------------
// destroy
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It>
struct Destroy : Dispatchable<Destroy<It>> {
    Partition<It> m_partition;

    Destroy(size_t count, size_t chunks, It first) : m_partition(first, count, chunks) {}

    void run(size_t ind) noexcept
    {
        auto p = m_partition.at(ind);
        std::destroy(p.first, p.last);
    }
};

} // namespace internal

template <class FwdIt>
void destroy(FwdIt first, FwdIt last) noexcept
{
    const auto count = std::distance(first, last);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Destroy<FwdIt> op{static_cast<size_t>(count), chunks, first};
            op.dispatch_apply(chunks);
            return;
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::destroy(first, last);
}

template <class FwdIt, class Size>
FwdIt destroy_n(FwdIt first, Size count) noexcept
{
    if( count < 1 )
        return first;

    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Destroy<FwdIt> op{static_cast<size_t>(count), chunks, first};
            op.dispatch_apply(chunks);
            return op.m_partition.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::destroy_n(first, count);
}

//--------------------------------------------------------------------------------------------------
// move
//--------------------------------------------------------------------------------------------------

namespace internal {

template <class It1, class It2>
struct Move : Dispatchable<Move<It1, It2>> {
    Partition<It1> m_partition1;
    Partition<It2> m_partition2;

    Move(size_t count, size_t chunks, It1 first1, It2 first2)
        : m_partition1(first1, count, chunks), m_partition2(first2, count, chunks)
    {
    }

    void run(size_t ind) noexcept
    {
        auto p1 = m_partition1.at(ind);
        auto p2 = m_partition2.at(ind);
        std::move(p1.first, p1.last, p2.first);
    }
};

} // namespace internal

template <class FwdIt1, class FwdIt2>
FwdIt2 move(FwdIt1 first1, FwdIt1 last1, FwdIt2 first2) noexcept
{
    const auto count = std::distance(first1, last1);
    const auto chunks = internal::work_chunks_min_fraction_1(count);
    if( chunks > 1 ) {
        try {
            internal::Move<FwdIt1, FwdIt2> op{static_cast<size_t>(count), chunks, first1, first2};
            op.dispatch_apply(chunks);
            return op.m_partition2.end();
        } catch( const internal::parallelism_exception & ) {
        }
    }
    return std::move(first1, last1, first2);
}

#if defined(PSTLD_INTERNAL_ARC)
} // inline namespace arc
#endif

} // namespace pstld

//--------------------------------------------------------------------------------------------------
//
// System-specific implementation details
//
//--------------------------------------------------------------------------------------------------

#if defined(PSTLD_INTERNAL_HEADER_ONLY) || defined(PSTLD_INTERNAL_IMPLEMENTATION_FILE)

    #include <sys/types.h>
    #include <sys/sysctl.h>
    #include <dispatch/dispatch.h>

namespace pstld {

    #if defined(PSTLD_INTERNAL_ARC)
inline namespace arc {
    #endif

namespace internal {

PSTLD_INTERNAL_IMPL size_t max_hw_threads() noexcept
{
    static const size_t threads = [] {
        int count;
        size_t count_len = sizeof(count);
        sysctlbyname("hw.physicalcpu_max", &count, &count_len, nullptr, 0);
        return static_cast<size_t>(count);
    }();
    return threads;
}

PSTLD_INTERNAL_IMPL void
dispatch_apply(size_t iterations, void *ctx, void (*function)(void *, size_t)) noexcept
{
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wnullability-extension"
    #if DISPATCH_APPLY_AUTO_AVAILABLE
        ::dispatch_apply_f(iterations, DISPATCH_APPLY_AUTO, ctx, function);
    #else
        ::dispatch_apply_f(iterations, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ctx, function);
    #endif
    #pragma clang diagnostic pop
}

PSTLD_INTERNAL_IMPL void dispatch_async(void *ctx, void (*function)(void *)) noexcept
{
    ::dispatch_async_f(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ctx, function);
}

PSTLD_INTERNAL_IMPL DispatchGroup::DispatchGroup() noexcept
    : m_group(dispatch_group_create()), m_queue(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0))
{
}

PSTLD_INTERNAL_IMPL DispatchGroup::~DispatchGroup()
{
    #if !defined(PSTLD_INTERNAL_ARC)
    ::dispatch_release(static_cast<dispatch_group_t>(m_group));
    #endif
}

PSTLD_INTERNAL_IMPL void DispatchGroup::dispatch(void *ctx, void (*function)(void *)) noexcept
{
    ::dispatch_group_async_f(static_cast<dispatch_group_t>(m_group),
                             static_cast<dispatch_queue_t>(m_queue),
                             ctx,
                             function);
}

PSTLD_INTERNAL_IMPL void DispatchGroup::wait() noexcept
{
    ::dispatch_group_wait(static_cast<dispatch_group_t>(m_group), DISPATCH_TIME_FOREVER);
}

PSTLD_INTERNAL_IMPL const char *parallelism_exception::what() const noexcept
{
    return "Failed to acquire resources to perform parallel computation";
}

PSTLD_INTERNAL_IMPL void parallelism_exception::raise()
{
    throw parallelism_exception{};
};

} // namespace internal

    #if defined(PSTLD_INTERNAL_ARC)
} // inline namespace arc
    #endif

} // namespace pstld

#endif // defined(PSTLD_INTERNAL_HEADER_ONLY) || defined(PSTLD_INTERNAL_IMPLEMENTATION_FILE)

//--------------------------------------------------------------------------------------------------
//
// Injecting the shims into ::std
//
//--------------------------------------------------------------------------------------------------

#if defined(PSTLD_INTERNAL_DO_HACK_INTO_STD)

#ifndef __cpp_lib_execution
#define __cpp_lib_execution 201902L
#endif

#ifndef __cpp_lib_parallel_algorithm
#define __cpp_lib_parallel_algorithm 201603L
#endif

namespace std {

namespace execution {

class sequenced_policy
{
public:
    static constexpr bool __pstld_enabled = false;
};
class parallel_policy
{
public:
    static constexpr bool __pstld_enabled = true;
};
class parallel_unsequenced_policy
{
public:
    static constexpr bool __pstld_enabled = true;
};
class unsequenced_policy
{
public:
    static constexpr bool __pstld_enabled = false;
};

inline constexpr sequenced_policy seq;
inline constexpr parallel_policy par;
inline constexpr parallel_unsequenced_policy par_unseq;
inline constexpr unsequenced_policy unseq;

template <class T>
struct is_execution_policy : std::false_type {
};
template <>
struct is_execution_policy<sequenced_policy> : std::true_type {
};
template <>
struct is_execution_policy<parallel_policy> : std::true_type {
};
template <>
struct is_execution_policy<parallel_unsequenced_policy> : std::true_type {
};
template <>
struct is_execution_policy<unsequenced_policy> : std::true_type {
};

template <class T>
inline constexpr bool is_execution_policy_v = is_execution_policy<T>::value;

template <class ExPo, class T>
using __enable_if_execution_policy =
    typename std::enable_if<is_execution_policy<typename std::decay<ExPo>::type>::value, T>::type;

template <class ExPo>
inline constexpr bool __pstld_enabled = std::remove_reference_t<ExPo>::__pstld_enabled;

} // namespace execution

// 25.6.1 - all_of /////////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It, class UnPred>
execution::__enable_if_execution_policy<ExPo, bool>
all_of(ExPo &&, It first, It last, UnPred p) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::all_of(first, last, p);
    else
        return ::std::all_of(first, last, p);
}

// 25.6.2 - any_of ////////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It, class UnPred>
execution::__enable_if_execution_policy<ExPo, bool>
any_of(ExPo &&, It first, It last, UnPred p) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::any_of(first, last, p);
    else
        return ::std::any_of(first, last, p);
}

// 25.6.3 - none_of ////////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It, class UnPred>
execution::__enable_if_execution_policy<ExPo, bool>
none_of(ExPo &&, It first, It last, UnPred p) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::none_of(first, last, p);
    else
        return ::std::none_of(first, last, p);
}

// 25.6.4 - for_each, for_each_n ///////////////////////////////////////////////////////////////////

template <class ExPo, class It, class Func>
execution::__enable_if_execution_policy<ExPo, void>
for_each(ExPo &&, It first, It last, Func f) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::for_each(first, last, f);
    else
        ::std::for_each(first, last, f);
}

template <class ExPo, class It, class Size, class Func>
execution::__enable_if_execution_policy<ExPo, It>
for_each_n(ExPo &&, It first, Size count, Func f) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::for_each_n(first, count, f);
    else
        return ::std::for_each_n(first, count, f);
}

// 25.6.5 - find, find_if, find_if_not /////////////////////////////////////////////////////////////

template <class ExPo, class It, class T>
execution::__enable_if_execution_policy<ExPo, It>
find(ExPo &&, It first, It last, const T &value) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::find(first, last, value);
    else
        return ::std::find(first, last, value);
}

template <class ExPo, class It, class Pred>
execution::__enable_if_execution_policy<ExPo, It>
find_if(ExPo &&, It first, It last, Pred pred) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::find_if(first, last, pred);
    else
        return ::std::find_if(first, last, pred);
}

template <class ExPo, class It, class Pred>
execution::__enable_if_execution_policy<ExPo, It>
find_if_not(ExPo &&, It first, It last, Pred pred) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::find_if_not(first, last, pred);
    else
        return ::std::find_if_not(first, last, pred);
}

// 25.6.6 - find_end ///////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, It1>
find_end(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::find_end(first1, last1, first2, last2);
    else
        return ::std::find_end(first1, last1, first2, last2);
}

template <class ExPo, class It1, class It2, class Pred>
execution::__enable_if_execution_policy<ExPo, It1>
find_end(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2, Pred pred)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::find_end(first1, last1, first2, last2, pred);
    else
        return ::std::find_end(first1, last1, first2, last2, pred);
}

// 25.6.7 - find_first_of //////////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, It1>
find_first_of(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::find_first_of(first1, last1, first2, last2);
    else
        return ::std::find_first_of(first1, last1, first2, last2);
}

template <class ExPo, class It1, class It2, class Pred>
execution::__enable_if_execution_policy<ExPo, It1>
find_first_of(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2, Pred pred) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::find_first_of(first1, last1, first2, last2, pred);
    else
        return ::std::find_first_of(first1, last1, first2, last2, pred);
}

// 25.6.8 - adjacent_find //////////////////////////////////////////////////////////////////////////

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, It> adjacent_find(ExPo &&, It first, It last) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::adjacent_find(first, last);
    else
        return ::std::adjacent_find(first, last);
}

template <class ExPo, class It, class Pred>
execution::__enable_if_execution_policy<ExPo, It>
adjacent_find(ExPo &&, It first, It last, Pred pred) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::adjacent_find(first, last, pred);
    else
        return ::std::adjacent_find(first, last, pred);
}

// 25.6.9 - count, count_if ////////////////////////////////////////////////////////////////////////

template <class ExPo, class It, class T>
execution::__enable_if_execution_policy<ExPo, typename std::iterator_traits<It>::difference_type>
count(ExPo &&, It first, It last, const T &value) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::count(first, last, value);
    else
        return ::std::count(first, last, value);
}

template <class ExPo, class It, class Pred>
execution::__enable_if_execution_policy<ExPo, typename std::iterator_traits<It>::difference_type>
count_if(ExPo &&, It first, It last, Pred pred) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::count_if(first, last, pred);
    else
        return ::std::count_if(first, last, pred);
}

// 25.6.10 - mismatch //////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, std::pair<It1, It2>>
mismatch(ExPo &&, It1 first1, It1 last1, It2 first2) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::mismatch(first1, last1, first2);
    else
        return ::std::mismatch(first1, last1, first2);
}

template <class ExPo, class It1, class It2, class Cmp>
execution::__enable_if_execution_policy<ExPo, std::pair<It1, It2>>
mismatch(ExPo &&, It1 first1, It1 last1, It2 first2, Cmp cmp) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::mismatch(first1, last1, first2, cmp);
    else
        return ::std::mismatch(first1, last1, first2, cmp);
}

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, std::pair<It1, It2>>
mismatch(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::mismatch(first1, last1, first2, last2);
    else
        return ::std::mismatch(first1, last1, first2, last2);
}

template <class ExPo, class It1, class It2, class Cmp>
execution::__enable_if_execution_policy<ExPo, std::pair<It1, It2>>
mismatch(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2, Cmp cmp) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::mismatch(first1, last1, first2, last2, cmp);
    else
        return ::std::mismatch(first1, last1, first2, last2, cmp);
}

// 25.6.11 - equal /////////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, bool>
equal(ExPo &&, It1 first1, It1 last1, It2 first2) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::equal(first1, last1, first2);
    else
        return ::std::equal(first1, last1, first2);
}

template <class ExPo, class It1, class It2, class Eq>
execution::__enable_if_execution_policy<ExPo, bool>
equal(ExPo &&, It1 first1, It1 last1, It2 first2, Eq eq) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::equal(first1, last1, first2, eq);
    else
        return ::std::equal(first1, last1, first2, eq);
}

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, bool>
equal(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::equal(first1, last1, first2, last2);
    else
        return ::std::equal(first1, last1, first2, last2);
}

template <class ExPo, class It1, class It2, class Eq>
execution::__enable_if_execution_policy<ExPo, bool>
equal(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2, Eq eq) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::equal(first1, last1, first2, last2, eq);
    else
        return ::std::equal(first1, last1, first2, last2, eq);
}

// 25.6.13 - search, search_n //////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, It1>
search(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::search(first1, last1, first2, last2);
    else
        return ::std::search(first1, last1, first2, last2);
}

template <class ExPo, class It1, class It2, class Pred>
execution::__enable_if_execution_policy<ExPo, It1>
search(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2, Pred pred) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::search(first1, last1, first2, last2, pred);
    else
        return ::std::search(first1, last1, first2, last2, pred);
}

template <class ExPo, class It, class Size, class T>
execution::__enable_if_execution_policy<ExPo, It>
search_n(ExPo &&, It first, It last, Size count, const T &value) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::search_n(first, last, count, value);
    else
        return ::std::search_n(first, last, count, value);
}

template <class ExPo, class It, class Size, class T, class Pred>
execution::__enable_if_execution_policy<ExPo, It>
search_n(ExPo &&, It first, It last, Size count, const T &value, Pred pred) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::search_n(first, last, count, value, pred);
    else
        return ::std::search_n(first, last, count, value, pred);
}

// 25.7.1 - copy, copy_n, copy_if //////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, It2>
copy(ExPo &&, It1 first, It1 last, It2 result) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::copy(first, last, result);
    else
        return ::std::copy(first, last, result);
}

template <class ExPo, class It1, class Size, class It2>
execution::__enable_if_execution_policy<ExPo, It2>
copy_n(ExPo &&, It1 first, Size count, It2 result) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::copy_n(first, count, result);
    else
        return ::std::copy_n(first, count, result);
}

template <class ExPo, class It1, class It2, class Pred>
execution::__enable_if_execution_policy<ExPo, It2>
copy_if(ExPo &&, It1 first, It1 last, It2 result, Pred pred) noexcept
{
    return ::std::copy_if(first, last, result, pred); // stub only
}

// 25.7.2 - move ///////////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, It2>
move(ExPo &&, It1 first, It1 last, It2 result) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::move(first, last, result);
    else
        return ::std::move(first, last, result);
}

// 25.7.3 - swap_ranges ////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, It2>
swap_ranges(ExPo &&, It1 first, It1 last, It2 result) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::swap_ranges(first, last, result);
    else
        return ::std::swap_ranges(first, last, result);
}

// 25.7.4 - transform //////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2, class UnOp>
execution::__enable_if_execution_policy<ExPo, It2>
transform(ExPo &&, It1 first1, It1 last1, It2 first2, UnOp op) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::transform(first1, last1, first2, op);
    else
        return ::std::transform(first1, last1, first2, op);
}

template <class ExPo, class It1, class It2, class It3, class UnOp>
execution::__enable_if_execution_policy<ExPo, It3>
transform(ExPo &&, It1 first1, It1 last1, It2 first2, It3 first3, UnOp op) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::transform(first1, last1, first2, first3, op);
    else
        return ::std::transform(first1, last1, first2, first3, op);
}

// 25.7.5 - replace, replace_if, replace_copy, replace_copy_if /////////////////////////////////////

template <class ExPo, class It, class T>
execution::__enable_if_execution_policy<ExPo, void>
replace(ExPo &&, It first, It last, const T &old_val, const T &new_val) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::replace(first, last, old_val, new_val);
    else
        ::std::replace(first, last, old_val, new_val);
}

template <class ExPo, class It, class Pred, class T>
execution::__enable_if_execution_policy<ExPo, void>
replace_if(ExPo &&, It first, It last, Pred pred, const T &new_val) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::replace_if(first, last, pred, new_val);
    else
        ::std::replace_if(first, last, pred, new_val);
}

template <class ExPo, class It1, class It2, class T>
execution::__enable_if_execution_policy<ExPo, It2>
replace_copy(ExPo &&, It1 first, It1 last, It2 result, const T &old_value, const T &new_value)
{
    // stub only
    return ::std::replace_copy(first, last, result, old_value, new_value);
}

template <class ExPo, class It1, class It2, class Pred, class T>
execution::__enable_if_execution_policy<ExPo, It2>
replace_copy_if(ExPo &&, It1 first, It1 last, It2 result, Pred pred, const T &new_value)
{
    // stub only
    return ::std::replace_copy_if(first, last, result, pred, new_value);
}

// 25.7.6 - fill, fill_n ///////////////////////////////////////////////////////////////////////////

template <class ExPo, class It, class T>
execution::__enable_if_execution_policy<ExPo, void>
fill(ExPo &&, It first, It last, const T &value) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::fill(first, last, value);
    else
        ::std::fill(first, last, value);
}

template <class ExPo, class It, class Size, class T>
execution::__enable_if_execution_policy<ExPo, It>
fill_n(ExPo &&, It first, Size count, const T &value) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::fill_n(first, count, value);
    else
        return ::std::fill_n(first, count, value);
}

// 25.7.7 - generate, generate_n ///////////////////////////////////////////////////////////////////

template <class ExPo, class It, class Gen>
execution::__enable_if_execution_policy<ExPo, void> generate(ExPo &&, It first, It last, Gen gen)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::generate(first, last, gen);
    else
        ::std::generate(first, last, gen);
}

template <class ExPo, class It, class Size, class Gen>
execution::__enable_if_execution_policy<ExPo, It> generate_n(ExPo &&, It first, Size count, Gen gen)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::generate_n(first, count, gen);
    else
        return ::std::generate_n(first, count, gen);
}

// 25.7.10 - reverse ///////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, void> reverse(ExPo &&, It first, It last)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::reverse(first, last);
    else
        ::std::reverse(first, last);
}

// 25.8.2.1 - sort /////////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, void> sort(ExPo &&, It first, It last)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::sort(first, last);
    else
        ::std::sort(first, last);
}

template <class ExPo, class It, class Cmp>
execution::__enable_if_execution_policy<ExPo, void> sort(ExPo &&, It first, It last, Cmp cmp)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::sort(first, last, cmp);
    else
        ::std::sort(first, last, cmp);
}

// 25.8.2.2 - stable_sort //////////////////////////////////////////////////////////////////////////

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, void> stable_sort(ExPo &&, It first, It last)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::stable_sort(first, last);
    else
        ::std::stable_sort(first, last);
}

template <class ExPo, class It, class Cmp>
execution::__enable_if_execution_policy<ExPo, void> stable_sort(ExPo &&, It first, It last, Cmp cmp)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::stable_sort(first, last, cmp);
    else
        ::std::stable_sort(first, last, cmp);
}

// 25.8.2.5 - is_sorted, is_sorted_until ///////////////////////////////////////////////////////////

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, bool> is_sorted(ExPo &&, It first, It last)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::is_sorted(first, last);
    else
        return ::std::is_sorted(first, last);
}

template <class ExPo, class It, class Cmp>
execution::__enable_if_execution_policy<ExPo, bool> is_sorted(ExPo &&, It first, It last, Cmp cmp)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::is_sorted(first, last, cmp);
    else
        return ::std::is_sorted(first, last, cmp);
}

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, It> is_sorted_until(ExPo &&, It first, It last)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::is_sorted_until(first, last);
    else
        return ::std::is_sorted_until(first, last);
}

template <class ExPo, class It, class Cmp>
execution::__enable_if_execution_policy<ExPo, It>
is_sorted_until(ExPo &&, It first, It last, Cmp cmp)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::is_sorted_until(first, last, cmp);
    else
        return ::std::is_sorted_until(first, last, cmp);
}

// 25.8.5 - is_partitioned /////////////////////////////////////////////////////////////////////////

template <class ExPo, class It, class Pred>
execution::__enable_if_execution_policy<ExPo, bool>
is_partitioned(ExPo &&, It first, It last, Pred pred)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::is_partitioned(first, last, pred);
    else
        return ::std::is_partitioned(first, last, pred);
}

// 25.8.6 - merge //////////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2, class It3>
execution::__enable_if_execution_policy<ExPo, It3>
merge(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2, It3 first3)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::merge(first1, last1, first2, last2, first3);
    else
        return ::std::merge(first1, last1, first2, last2, first3);
}

template <class ExPo, class It1, class It2, class It3, class Cmp>
execution::__enable_if_execution_policy<ExPo, It3>
merge(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2, It3 first3, Cmp cmp)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::merge(first1, last1, first2, last2, first3, cmp);
    else
        return ::std::merge(first1, last1, first2, last2, first3, cmp);
}

// 25.8.9 - min_element, max_element, minmax_element ///////////////////////////////////////////////

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, It> min_element(ExPo &&, It first, It last)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::min_element(first, last);
    else
        return ::std::min_element(first, last);
}

template <class ExPo, class It, class Cmp>
execution::__enable_if_execution_policy<ExPo, It> min_element(ExPo &&, It first, It last, Cmp cmp)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::min_element(first, last, cmp);
    else
        return ::std::min_element(first, last, cmp);
}

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, It> max_element(ExPo &&, It first, It last)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::max_element(first, last);
    else
        return ::std::max_element(first, last);
}

template <class ExPo, class It, class Cmp>
execution::__enable_if_execution_policy<ExPo, It> max_element(ExPo &&, It first, It last, Cmp cmp)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::max_element(first, last, cmp);
    else
        return ::std::max_element(first, last, cmp);
}

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, std::pair<It, It>>
minmax_element(ExPo &&, It first, It last)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::minmax_element(first, last);
    else
        return ::std::minmax_element(first, last);
}

template <class ExPo, class It, class Cmp>
execution::__enable_if_execution_policy<ExPo, std::pair<It, It>>
minmax_element(ExPo &&, It first, It last, Cmp cmp)
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::minmax_element(first, last, cmp);
    else
        return ::std::minmax_element(first, last, cmp);
}

// 25.8.11 - lexicographical_compare ///////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, bool>
lexicographical_compare(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::lexicographical_compare(first1, last1, first2, last2);
    else
        return ::std::lexicographical_compare(first1, last1, first2, last2);
}

template <class ExPo, class It1, class It2, class Cmp>
execution::__enable_if_execution_policy<ExPo, bool>
lexicographical_compare(ExPo &&, It1 first1, It1 last1, It2 first2, It2 last2, Cmp cmp) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::lexicographical_compare(first1, last1, first2, last2, cmp);
    else
        return ::std::lexicographical_compare(first1, last1, first2, last2, cmp);
}

// 25.10.4 - reduce ////////////////////////////////////////////////////////////////////////////////

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, typename iterator_traits<It>::value_type>
reduce(ExPo &&, It first, It last) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::reduce(first, last);
    else
        return ::std::reduce(first, last);
}

template <class ExPo, class It, class T>
execution::__enable_if_execution_policy<ExPo, T> reduce(ExPo &&, It first, It last, T val) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::reduce(first, last, std::move(val));
    else
        return ::pstld::internal::move_reduce(first, last, std::move(val), std::plus<>{});
}

template <class ExPo, class It, class T, class BinOp>
execution::__enable_if_execution_policy<ExPo, T>
reduce(ExPo &&, It first, It last, T val, BinOp op) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::reduce(first, last, std::move(val), op);
    else
        return ::pstld::internal::move_reduce(first, last, std::move(val), op);
}

// 25.10.6 - transform_reduce //////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2, class T>
execution::__enable_if_execution_policy<ExPo, T>
transform_reduce(ExPo &&, It1 first1, It1 last1, It2 first2, T val) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::transform_reduce(first1, last1, first2, std::move(val));
    else
        return ::pstld::internal::move_transform_reduce(
            first1, last1, first2, std::move(val), std::plus<>{}, std::multiplies<>{});
}

template <class ExPo, class It1, class It2, class T, class BinRedOp, class BinTrOp>
execution::__enable_if_execution_policy<ExPo, T> transform_reduce(ExPo &&,
                                                                  It1 first1,
                                                                  It1 last1,
                                                                  It2 first2,
                                                                  T val,
                                                                  BinRedOp redop,
                                                                  BinTrOp trop) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::transform_reduce(first1, last1, first2, std::move(val), redop, trop);
    else
        return ::pstld::internal::move_transform_reduce(
            first1, last1, first2, std::move(val), redop, trop);
}

template <class ExPo, class It, class T, class BinOp, class UnOp>
execution::__enable_if_execution_policy<ExPo, T>
transform_reduce(ExPo &&, It first, It last, T val, BinOp bop, UnOp uop) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::transform_reduce(first, last, std::move(val), bop, uop);
    else
        return ::pstld::internal::move_transform_reduce(first, last, std::move(val), bop, uop);
}

// 25.10.8 - exclusive_scan ////////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2, class T>
execution::__enable_if_execution_policy<ExPo, It2>
exclusive_scan(ExPo &&, It1 first1, It1 last1, It2 first2, T val) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::exclusive_scan(first1, last1, first2, std::move(val));
    else
        return ::std::exclusive_scan(first1, last1, first2, std::move(val));
}

template <class ExPo, class It1, class It2, class T, class BinOp>
execution::__enable_if_execution_policy<ExPo, It2>
exclusive_scan(ExPo &&, It1 first1, It1 last1, It2 first2, T val, BinOp bop) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::exclusive_scan(first1, last1, first2, std::move(val), bop);
    else
        return ::std::exclusive_scan(first1, last1, first2, std::move(val), bop);
}

// 25.10.9 - inclusive_scan ////////////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2, class BinOp, class T>
execution::__enable_if_execution_policy<ExPo, It2>
inclusive_scan(ExPo &&, It1 first1, It1 last1, It2 first2, BinOp bop, T val) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::inclusive_scan(first1, last1, first2, bop, std::move(val));
    else
        return ::std::inclusive_scan(first1, last1, first2, bop, std::move(val));
}

template <class ExPo, class It1, class It2, class BinOp>
execution::__enable_if_execution_policy<ExPo, It2>
inclusive_scan(ExPo &&, It1 first1, It1 last1, It2 first2, BinOp bop) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::inclusive_scan(first1, last1, first2, bop);
    else
        return ::std::inclusive_scan(first1, last1, first2, bop);
}

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, It2>
inclusive_scan(ExPo &&, It1 first1, It1 last1, It2 first2) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::inclusive_scan(first1, last1, first2);
    else
        return ::std::inclusive_scan(first1, last1, first2);
}

// 25.10.10 - transform_exclusive_scan /////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2, class T, class BinOp, class UnOp>
execution::__enable_if_execution_policy<ExPo, It2> transform_exclusive_scan(ExPo &&,
                                                                            It1 first1,
                                                                            It1 last1,
                                                                            It2 first2,
                                                                            T val,
                                                                            BinOp bop,
                                                                            UnOp uop) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::transform_exclusive_scan(first1, last1, first2, std::move(val), bop, uop);
    else
        return ::pstld::internal::transform_exclusive_scan_serial(
            first1, last1, first2, std::move(val), bop, uop);
}

// 25.10.11 - transform_inclusive_scan /////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2, class BinOp, class UnOp, class T>
execution::__enable_if_execution_policy<ExPo, It2> transform_inclusive_scan(ExPo &&,
                                                                            It1 first1,
                                                                            It1 last1,
                                                                            It2 first2,
                                                                            BinOp bop,
                                                                            UnOp uop,
                                                                            T val) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::transform_inclusive_scan(first1, last1, first2, bop, uop, std::move(val));
    else
        return ::std::transform_inclusive_scan(first1, last1, first2, bop, uop, std::move(val));
}

template <class ExPo, class It1, class It2, class BinOp, class UnOp>
execution::__enable_if_execution_policy<ExPo, It2>
transform_inclusive_scan(ExPo &&, It1 first1, It1 last1, It2 first2, BinOp bop, UnOp uop) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::transform_inclusive_scan(first1, last1, first2, bop, uop);
    else
        return ::std::transform_inclusive_scan(first1, last1, first2, bop, uop);
}

// 25.10.12 - adjacent_difference //////////////////////////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, It2>
adjacent_difference(ExPo &&, It1 first1, It1 last1, It2 first2) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::adjacent_difference(first1, last1, first2);
    else
        return ::std::adjacent_difference(first1, last1, first2);
}

template <class ExPo, class It1, class It2, class BinOp>
execution::__enable_if_execution_policy<ExPo, It2>
adjacent_difference(ExPo &&, It1 first1, It1 last1, It2 first2, BinOp op) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::adjacent_difference(first1, last1, first2, op);
    else
        return ::std::adjacent_difference(first1, last1, first2, op);
}

// 25.11.3 - uninitialized_default_construct, uninitialized_default_construct_n ////////////////////

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, void>
uninitialized_default_construct(ExPo &&, It first, It last) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::uninitialized_default_construct(first, last);
    else
        ::std::uninitialized_default_construct(first, last);
}

template <class ExPo, class It, class Size>
execution::__enable_if_execution_policy<ExPo, It>
uninitialized_default_construct_n(ExPo &&, It first, Size count) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::uninitialized_default_construct_n(first, count);
    else
        return ::std::uninitialized_default_construct_n(first, count);
}

// 25.11.4 - uninitialized_value_construct, uninitialized_value_construct_n ////////////////////////

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, void>
uninitialized_value_construct(ExPo &&, It first, It last) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::uninitialized_value_construct(first, last);
    else
        ::std::uninitialized_value_construct(first, last);
}

template <class ExPo, class It, class Size>
execution::__enable_if_execution_policy<ExPo, It>
uninitialized_value_construct_n(ExPo &&, It first, Size count) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::uninitialized_value_construct_n(first, count);
    else
        return ::std::uninitialized_value_construct_n(first, count);
}

// 25.11.5 - uninitialized_copy, uninitialized_copy_n //////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, It2>
uninitialized_copy(ExPo &&, It1 first, It1 last, It2 result) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::uninitialized_copy(first, last, result);
    else
        return ::std::uninitialized_copy(first, last, result);
}

template <class ExPo, class It1, class Size, class It2>
execution::__enable_if_execution_policy<ExPo, It2>
uninitialized_copy_n(ExPo &&, It1 first, Size count, It2 result) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::uninitialized_copy_n(first, count, result);
    else
        return ::std::uninitialized_copy_n(first, count, result);
}

// 25.11.6 - uninitialized_move, uninitialized_move_n //////////////////////////////////////////////

template <class ExPo, class It1, class It2>
execution::__enable_if_execution_policy<ExPo, It2>
uninitialized_move(ExPo &&, It1 first, It1 last, It2 result) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::uninitialized_move(first, last, result);
    else
        return ::std::uninitialized_move(first, last, result);
}

template <class ExPo, class It1, class Size, class It2>
execution::__enable_if_execution_policy<ExPo, std::pair<It1, It2>>
uninitialized_move_n(ExPo &&, It1 first, Size count, It2 result) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::uninitialized_move_n(first, count, result);
    else
        return ::std::uninitialized_move_n(first, count, result);
}

// 25.11.7 - uninitialized_fill, uninitialized_fill_n //////////////////////////////////////////////

template <class ExPo, class It, class T>
execution::__enable_if_execution_policy<ExPo, void>
uninitialized_fill(ExPo &&, It first, It last, const T &value) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::uninitialized_fill(first, last, value);
    else
        ::std::uninitialized_fill(first, last, value);
}

template <class ExPo, class It, class Size, class T>
execution::__enable_if_execution_policy<ExPo, It>
uninitialized_fill_n(ExPo &&, It first, Size count, const T &value) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::uninitialized_fill_n(first, count, value);
    else
        return ::std::uninitialized_fill_n(first, count, value);
}

// 25.11.9 - destroy, destroy_n ////////////////////////////////////////////////////////////////////

template <class ExPo, class It>
execution::__enable_if_execution_policy<ExPo, void> destroy(ExPo &&, It first, It last) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        ::pstld::destroy(first, last);
    else
        ::std::destroy(first, last);
}

template <class ExPo, class It, class Size>
execution::__enable_if_execution_policy<ExPo, It> destroy_n(ExPo &&, It first, Size count) noexcept
{
    if constexpr( execution::__pstld_enabled<ExPo> )
        return ::pstld::destroy_n(first, count);
    else
        return ::std::destroy_n(first, count);
}

} // namespace std

#endif // defined(PSTLD_INTERNAL_DO_HACK_INTO_STD)
