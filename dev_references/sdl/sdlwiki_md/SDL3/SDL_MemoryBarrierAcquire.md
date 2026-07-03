# SDL_MemoryBarrierAcquire

Insert a memory acquire barrier (macro version).

## Header File

Defined in
[\<SDL3/SDL_atomic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_atomic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_MemoryBarrierAcquire() SDL_MemoryBarrierAcquireFunction()
```

</div>

## Remarks

Please see [SDL_MemoryBarrierRelease](SDL_MemoryBarrierRelease.html) for
the details on what memory barriers are and when to use them.

This is the macro version of this functionality; if possible, SDL will
use compiler intrinsics or inline assembly, but some platforms might
need to call the function version of this,
[SDL_MemoryBarrierAcquireFunction](SDL_MemoryBarrierAcquireFunction.html),
to do the heavy lifting. Apps that can use the macro should favor it
over the function.

## Thread Safety

Obviously this macro is safe to use from any thread at any time, but if
you find yourself needing this, you are probably dealing with some very
sensitive code; be careful!

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_MemoryBarrierRelease](SDL_MemoryBarrierRelease.html)
- [SDL_MemoryBarrierAcquireFunction](SDL_MemoryBarrierAcquireFunction.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAtomic](CategoryAtomic.html)
