# SDL_CompareAndSwapAtomicU32

Set an atomic variable to a new value if it is currently an old value.

## Header File

Defined in
[\<SDL3/SDL_atomic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_atomic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_CompareAndSwapAtomicU32(SDL_AtomicU32 *a, Uint32 oldval, Uint32 newval);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AtomicU32](SDL_AtomicU32.html) \* | **a** | a pointer to an [SDL_AtomicU32](SDL_AtomicU32.html) variable to be modified. |
| [Uint32](Uint32.html) | **oldval** | the old value. |
| [Uint32](Uint32.html) | **newval** | the new value. |

## Return Value

(bool) Returns true if the atomic variable was set, false otherwise.

## Remarks

***Note: If you don't know what this function is for, you shouldn't use
it!***

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetAtomicU32](SDL_GetAtomicU32.html)
- [SDL_SetAtomicU32](SDL_SetAtomicU32.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAtomic](CategoryAtomic.html)
