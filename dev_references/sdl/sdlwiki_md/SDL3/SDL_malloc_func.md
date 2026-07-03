# SDL_malloc_func

A callback used to implement [SDL_malloc](SDL_malloc.html)().

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void *(SDLCALL *SDL_malloc_func)(size_t size);
```

</div>

## Function Parameters

|          |                       |
|----------|-----------------------|
| **size** | the size to allocate. |

## Return Value

Returns a pointer to the allocated memory, or NULL if allocation failed.

## Remarks

SDL will always ensure that the passed `size` is greater than 0.

## Thread Safety

It should be safe to call this callback from any thread.

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_malloc](SDL_malloc.html)
- [SDL_GetOriginalMemoryFunctions](SDL_GetOriginalMemoryFunctions.html)
- [SDL_GetMemoryFunctions](SDL_GetMemoryFunctions.html)
- [SDL_SetMemoryFunctions](SDL_SetMemoryFunctions.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryStdinc](CategoryStdinc.html)
