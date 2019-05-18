---
layout: post
title:  "Are C++ Threads Preemptive?"
tags: c++ os
excerpt: What does the standard say?
published: true
author: fatih
---

Although we have a consensus on our desktops, servers and phones that an OS should provide preemptive threads, not all software is written for such environments and neither all operating systems support preemptive threads. I believe there's a case for non-preemptive (or cooperative) threads in special applications. But that's the topic of another article.

In this article, I'd like to see if the C++ standard allows for `std::thread`s to have cooperative semantics rather than preemptive.

All the `std::thread` implementations I have provide preemptive threads. This is expected however, as they are all for Win32 or POSIX interfaces, which themselves support preemptive threads. As far as I can see, there's no `std::thread` implementation that provides cooperative threads in the wild.

So we have to dive into the standard to find our answer. The C++ standard {% cite cppstd %} defines what a thread is as in [intro.multithread]:

> A thread of execution (also known as a thread) is a single flow of control within a program, including the initial invocation of a specific top-level function, and recursively including every function invocation subsequently executed by the thread.

No mention of preemption, so we have to keep looking.

The next interesting information is in [intro.progress], which defines what making progress for a C++ thread means:

> The implementation may assume that any thread will eventually do one of the following:
> + terminate,
> + make a call to a library I/O function,
> + perform an access through a volatile glvalue, or
> + perform a synchronization operation or an atomic operation.

This is _somewhat_ more related to what we're looking for, but is still not mentioning anything regarding preemption. The previous requirements can be made for both preemptive and cooperative threads.

However, something more interesting is in the 7th point:

> For a thread of execution providing concurrent forward progress guarantees, the implementation ensures that the thread will eventually make progress for as long as it has not terminated. [ Note: This is required regardless of whether or not other threads of executions (if any) have been or are making progress. To eventually fulfill this requirement means that this will happen in an unspecified but finite amount of time. — end note ]

Making progress here means doing something that has visible effects, in a hand wavy way. The interesting bit is in the note however. It states that a thread must be able to make progress in a finite amount of time. Thus, I believe _it kind of_ follows that cooperative threads **cannot provide** concurrent forward progress guarantees.

Imagine the following program:

```cpp
atomic<bool> b = false;
auto t1 = std::thread([]{
    while(!b);
});
auto t2 = std::thread([]{
    b = true;
    print(uart, "foo");
});
```

If the first thread `t1` starts executing first, it'll be stuck in the loop forever, thus starving `t2`. This means that `t2` may not make progress in a finite amount of time. Providing such a guarantee is impossible without either implementing preemptive threads, or instrumenting atomic accesses (and volatiles?) to potentially yield. 

However, the next bullet in the standard says the following:

> It is implementation-defined whether the implementation-created thread of execution that executes main ([basic.start.main]) and the threads of execution created by std::thread ([thread.thread.class]) provide concurrent forward progress guarantees. [ Note: General-purpose implementations should provide these guarantees. — end note ]

This states that if `std::thread`s provide concurrent forward progress guarantee or not is implementation defined. So, if I'm implementing the `std::thread`, I don't really have to do preemptive threads. A cooperative thread is certainly a standard conforming implementation. 

However, the point of implementing the `std::thread` API would be to ease the effort of porting programs to such an OS. I don't have any data on this, but I'm pretty certain most (>90% ?) `std::thread` usage assumes a preemptive threading model. Thus, supporting such programs would probably give a false sense of portability and would cause a lot of misunderstandings. Thus, I don't believe cooperative threads should implement a `std::thread` interface, even though it's completely legal to do so.

## References

{% bibliography --cited %}