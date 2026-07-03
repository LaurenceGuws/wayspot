# SDL_DetachThread

Let a thread clean up on exit without intervention.

## Header File

Defined in
[\<SDL3/SDL_thread.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_thread.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DetachThread(SDL_Thread *thread);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Thread](SDL_Thread.html) \* | **thread** | the [SDL_Thread](SDL_Thread.html) pointer that was returned from the [SDL_CreateThread](SDL_CreateThread.html)() call that started this thread. |

## Remarks

A thread may be "detached" to signify that it should not remain until
another thread has called [SDL_WaitThread](SDL_WaitThread.html)() on it.
Detaching a thread is useful for long-running threads that nothing needs
to synchronize with or further manage. When a detached thread is done,
it simply goes away.

There is no way to recover the return code of a detached thread. If you
need this, don't detach the thread and instead use
[SDL_WaitThread](SDL_WaitThread.html)().

Once a thread is detached, you should usually assume the
[SDL_Thread](SDL_Thread.html) isn't safe to reference again, as it will
become invalid immediately upon the detached thread's exit, instead of
remaining until someone has called
[SDL_WaitThread](SDL_WaitThread.html)() to finally clean it up. As such,
don't detach the same thread more than once.

If a thread has already exited when passed to
[SDL_DetachThread](SDL_DetachThread.html)(), it will stop waiting for a
call to [SDL_WaitThread](SDL_WaitThread.html)() and clean up
immediately. It is not safe to detach a thread that might be used with
[SDL_WaitThread](SDL_WaitThread.html)().

You may not call [SDL_WaitThread](SDL_WaitThread.html)() on a thread
that has been detached. Use either that function or this one, but not
both, or behavior is undefined.

It is safe to pass NULL to this function; it is a no-op.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
extern int TestThread(void *ptr);
SDL_Thread *thread = SDL_CreateThread(TestThread, "TestThread", (void *)NULL);
SDL_DetachThread(thread);  /* will go away on its own upon completion. */
```

</div>

## See Also

- [SDL_CreateThread](SDL_CreateThread.html)
- [SDL_WaitThread](SDL_WaitThread.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryThread](CategoryThread.html)
