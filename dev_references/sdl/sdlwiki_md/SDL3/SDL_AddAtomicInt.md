# SDL_AddAtomicInt

Add to an atomic variable.

## Header File

Defined in
[\<SDL3/SDL_atomic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_atomic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_AddAtomicInt(SDL_AtomicInt *a, int v);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AtomicInt](SDL_AtomicInt.html) \* | **a** | a pointer to an [SDL_AtomicInt](SDL_AtomicInt.html) variable to be modified. |
| int | **v** | the desired value to add. |

## Return Value

(int) Returns the previous value of the atomic variable.

## Remarks

This function also acts as a full memory barrier.

***Note: If you don't know what this function is for, you shouldn't use
it!***

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AtomicDecRef](SDL_AtomicDecRef.html)
- [SDL_AtomicIncRef](SDL_AtomicIncRef.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAtomic](CategoryAtomic.html)
