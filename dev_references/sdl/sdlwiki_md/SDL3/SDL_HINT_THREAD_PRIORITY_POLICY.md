# SDL_HINT_THREAD_PRIORITY_POLICY

A string specifying additional information to use with
[SDL_SetCurrentThreadPriority](SDL_SetCurrentThreadPriority.html).

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_THREAD_PRIORITY_POLICY "SDL_THREAD_PRIORITY_POLICY"
```

</div>

## Remarks

By default
[SDL_SetCurrentThreadPriority](SDL_SetCurrentThreadPriority.html) will
make appropriate system changes in order to apply a thread priority. For
example on systems using pthreads the scheduler policy is changed
automatically to a policy that works well with a given priority. Code
which has specific requirements can override SDL's default behavior with
this hint.

pthread hint values are "current", "other", "fifo" and "rr". Currently
no other platform hint values are defined but may be in the future.

On Linux, the kernel may send SIGKILL to realtime tasks which exceed the
distro configured execution budget for rtkit. This budget can be queried
through RLIMIT_RTTIME after calling
[SDL_SetCurrentThreadPriority](SDL_SetCurrentThreadPriority.html)().

This hint should be set before calling
[SDL_SetCurrentThreadPriority](SDL_SetCurrentThreadPriority.html)()

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
