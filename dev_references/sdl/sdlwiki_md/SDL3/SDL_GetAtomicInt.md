# SDL_GetAtomicInt

Get the value of an atomic variable.

## Header File

Defined in
[\<SDL3/SDL_atomic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_atomic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetAtomicInt(SDL_AtomicInt *a);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AtomicInt](SDL_AtomicInt.html) \* | **a** | a pointer to an [SDL_AtomicInt](SDL_AtomicInt.html) variable. |

## Return Value

(int) Returns the current value of an atomic variable.

## Remarks

***Note: If you don't know what this function is for, you shouldn't use
it!***

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetAtomicInt](SDL_SetAtomicInt.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAtomic](CategoryAtomic.html)
