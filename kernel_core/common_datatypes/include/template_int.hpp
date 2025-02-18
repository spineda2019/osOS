/*
 * Copyright 2024 Sebastian Pineda
 */

#ifndef KERNEL_CORE_COMMON_DATATYPES_INCLUDE_TEMPLATE_INT_HPP_
#define KERNEL_CORE_COMMON_DATATYPES_INCLUDE_TEMPLATE_INT_HPP_

#ifdef __cplusplus

template <class T>
concept SupportsSimpleOperations = requires(T instance) {
    instance + instance;
    instance - instance;
    instance* instance;
    instance / instance;
};

template <SupportsSimpleOperations T, int S>
struct FixedWidthInt {
    T inner_ : S;

    explicit FixedWidthInt(T primitive) : inner_{primitive} {}
    explicit FixedWidthInt() : inner_{0} {}
    T Raw() { return inner_; }
} __attribute__((packed));

#endif  // __cplusplus

#endif  // KERNEL_CORE_COMMON_DATATYPES_INCLUDE_TEMPLATE_INT_HPP_
