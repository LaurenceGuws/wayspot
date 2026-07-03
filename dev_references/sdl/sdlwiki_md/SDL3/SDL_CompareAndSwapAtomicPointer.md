# SDL_CompareAndSwapAtomicPointer

Set a pointer to a new value if it is currently an old value.

## Header File

Defined in
[\<SDL3/SDL_atomic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_atomic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_CompareAndSwapAtomicPointer(void **a, void *oldval, void *newval);
```

</div>

## Function Parameters

|           |            |                         |
|-----------|------------|-------------------------|
| void \*\* | **a**      | a pointer to a pointer. |
| void \*   | **oldval** | the old pointer value.  |
| void \*   | **newval** | the new pointer value.  |

## Return Value

(bool) Returns true if the pointer was set, false otherwise.

## Remarks

***Note: If you don't know what this function is for, you shouldn't use
it!***

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CompareAndSwapAtomicInt](SDL_CompareAndSwapAtomicInt.html)
- [SDL_GetAtomicPointer](SDL_GetAtomicPointer.html)
- [SDL_SetAtomicPointer](SDL_SetAtomicPointer.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAtomic](CategoryAtomic.html)
