# SDL_GetAtomicPointer

Get the value of a pointer atomically.

## Header File

Defined in
[\<SDL3/SDL_atomic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_atomic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void * SDL_GetAtomicPointer(void **a);
```

</div>

## Function Parameters

|           |       |                         |
|-----------|-------|-------------------------|
| void \*\* | **a** | a pointer to a pointer. |

## Return Value

(void \*) Returns the current value of a pointer.

## Remarks

***Note: If you don't know what this function is for, you shouldn't use
it!***

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CompareAndSwapAtomicPointer](SDL_CompareAndSwapAtomicPointer.html)
- [SDL_SetAtomicPointer](SDL_SetAtomicPointer.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAtomic](CategoryAtomic.html)
