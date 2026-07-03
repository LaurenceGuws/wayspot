# SDL_AtomicDecRef

Decrement an atomic variable used as a reference count.

## Header File

Defined in
[\<SDL3/SDL_atomic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_atomic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_AtomicDecRef(a)    (SDL_AddAtomicInt(a, -1) == 1)
```

</div>

## Macro Parameters

|       |                                                                   |
|-------|-------------------------------------------------------------------|
| **a** | a pointer to an [SDL_AtomicInt](SDL_AtomicInt.html) to decrement. |

## Return Value

Returns true if the variable reached zero after decrementing, false
otherwise.

## Remarks

***Note: If you don't know what this macro is for, you shouldn't use
it!***

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_AtomicIncRef](SDL_AtomicIncRef.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAtomic](CategoryAtomic.html)
