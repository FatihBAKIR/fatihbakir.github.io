---
layout: post
title:  "How to expect the unexpected"
tags: c++ embedded os
excerpt: Can we deal with bad expected objects in embedded systems?
published: true
author: fatih
---

Although C++ has a sophisticated error handling mechanism, ie exceptions, in embedded domains they are
usually disabled due to code size spent on jump table sizes with zero overhead exceptions or the runtime
overhead in other implementations. And in projects they are enabled, their use is usually frowned upon
due to the extreme costs of throwing an exception. It's said that you should only throw an exception
in exceptional situations, though what constitutes an exceptional situation is not well defined.

Anyway, due to these reasons, the C++ community has been in search of better error handling mechanisms.
While some {% cite herbceptions %} are working on fixing exceptions with core language changes, some 
{% cite boostoutcome %}, {% cite expected %} are working on going a different, purely library based route.

I personally like and use the expected objects as the return value from fallible functions. They encapsulate
the reason for the failure if something fails, so it's better for the caller to get such information.

However, there are a few pain points I have with it:

**They don't easily compose**

If you have a function `expected<T, foo_errors> foo();` and another `expected<T, bar_errors> bar();`, which
calls `foo`, it's difficult to return it's error value directly. Either you have to put all the values of
`foo_errors` to `bar_errors`, or simply discard that and put a single `foo_failed` in `bar_errors`. That's
not really nice. You could change bar to be `expected<T, variant<foo_errors, bar_errors>>` to make a better
interface, but it just goes deeper and deeper and still doesn't compose automatically, you have to keep
track of the error types of every callee in a function.

However, I can live with this.

**They don't work in embedded**

```cpp
expected<float, int> foo() { return unexpected(42); }

auto r = foo();
std::cout << r.value() << '\n';
```

What does this program do?

According to the proposal, and the reference implementation, it throws an exception. But the reason I've
picked this library is it was kind of promising to replace exceptions for me. Though the purpose of the paper
isn't exactly that, I think we might actually solve this.

The main problem it's useless in embedded is that the `expected::value` function, which promises to return
the internal value unconditionally. We want a tighter interface. For it to be usable in a mission critical
domain, it has to enforce the error checking at compile time.

## `tos::expected`

This is a type we provide in our embedded operating system. It simply privately inherits from `tl::expected`
and exposes a much more restricted interface. In short, there's only _safe_ functions for accessing the 
internal value:

1. `with`
2. `get_or`
3. `operator std::optional<T>`
4. `force_get`

The first one is simple, you call it with an expected, and pass 2 lambdas, one for when there's a value, and
one for when there's an error:

```cpp
with(fallible_func(), [](auto& val) {
    ... use val ...
}, [](auto& err){
    ... use err ...
});
```

It's statically enforced that you can't try to access the internal value if there's none.

The second one is simply a refinement over `with`, it basically tries to get the internal value, and if
there's no value, it returns another value passed to the function:

```cpp
auto v = get_or(fallible_func(), 705);
```

This doesn't let you handle the error explicitly, but you still can't access a non-existent value, enforced
at compile time.

The third one is a little convenience conversion operator for times when you don't care about the error at all
and just want to get a `std::optional`. The operator is explicit, so you don't get any unexpected (see the pun?)
conversions. However, this is a bit dangerous as `std::optional` doesn't enforce checking the error at compile
time as we do.

Finally, `force_get`. Despite it's name, it doesn't really force anything. When you call this function, if there's
no value in the expected object, the kernel panics. So, no undefined behavior, but still not really a desirable
thing to have in your systems.

However, the use case is definitely not calling it on random `expected`s. The use case is to call this function
only when you _know_ there's a value in the expected:

```cpp
auto e = fallible_func();

if (!e) return;

auto& v = force_get(e);
```

Since you check the expected before accessing `e`, there's no risk of a kernel panic.

However, as you might've guessed, we can't enforce this at compile time.

Or can we?

Although it's not completely standard, there's a hack we use to enforce this. We can't really enforce this
at the compiler since the types don't care about the control flow.

However, using some tricks, we can actually detect whether you've missed to check an error. The trick is to
always inline the `force_get` call, and have a special hook to call when it fails:

```cpp
decltype(auto) ALWAYS_INLINE force_get(ExpectedT&& e)
{
    if (e)
    {
        return *e.m_internal;
    }

    tos_force_get_failed(nullptr);
}
```

`expected::m_internal` is a `tl::expected`. As you can see, we have an always inline function that repeats
the check we're supposed to do in the scope we should call it. This means that the compiler will see that
we're doing a redundant check, and drop the if that's coming from `force_get`. Since it drops the if, the
branch that calls `tos_force_get_failed` disappears completely. Therefore, we don't get any runtime overhead
for doing this. 

We also use link time size optimizations such as garbage collecting unused symbols. In a program that always
checks whether there's a value before calling `force_get`, the `tos_force_get_failed` symbol must be unused,
and thus should not appear in the final binary. Therefore, with a single `nm | grep tos_force_get_failed`,
we can determine whether we've called `force_get` on an unknown expected.

Obviously, this won't give you a lot of information regarding where you've forgot to check the expected, but
it's better to realize you've forgotten to check it before programming the device rather than after crashing
at runtime.

## References

{% bibliography --cited %}