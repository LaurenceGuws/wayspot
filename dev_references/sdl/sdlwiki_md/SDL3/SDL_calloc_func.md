# SDL_calloc_func

A callback used to implement [SDL_calloc](SDL_calloc.html)().

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void *(SDLCALL *SDL_calloc_func)(size_t nmemb, size_t size);
```

</div>

## Function Parameters

|           |                                        |
|-----------|----------------------------------------|
| **nmemb** | the number of elements in the array.   |
| **size**  | the size of each element of the array. |

## Return Value

Returns a pointer to the allocated array, or NULL if allocation failed.

## Remarks

SDL will always ensure that the passed `nmemb` and `size` are both
greater than 0.

## Thread Safety

It should be safe to call this callback from any thread.

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_calloc](SDL_calloc.html)
- [SDL_GetOriginalMemoryFunctions](SDL_GetOriginalMemoryFunctions.html)
- [SDL_GetMemoryFunctions](SDL_GetMemoryFunctions.html)
- [SDL_SetMemoryFunctions](SDL_SetMemoryFunctions.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryStdinc](CategoryStdinc.html)
