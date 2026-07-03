# SDL_free_func

A callback used to implement [SDL_free](SDL_free.html)().

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void (SDLCALL *SDL_free_func)(void *mem);
```

</div>

## Function Parameters

|         |                                |
|---------|--------------------------------|
| **mem** | a pointer to allocated memory. |

## Remarks

SDL will always ensure that the passed `mem` is a non-NULL pointer.

## Thread Safety

It should be safe to call this callback from any thread.

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_free](SDL_free.html)
- [SDL_GetOriginalMemoryFunctions](SDL_GetOriginalMemoryFunctions.html)
- [SDL_GetMemoryFunctions](SDL_GetMemoryFunctions.html)
- [SDL_SetMemoryFunctions](SDL_SetMemoryFunctions.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryStdinc](CategoryStdinc.html)
