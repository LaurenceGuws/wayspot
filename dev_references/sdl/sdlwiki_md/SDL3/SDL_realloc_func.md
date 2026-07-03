# SDL_realloc_func

A callback used to implement [SDL_realloc](SDL_realloc.html)().

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void *(SDLCALL *SDL_realloc_func)(void *mem, size_t size);
```

</div>

## Function Parameters

|          |                                                       |
|----------|-------------------------------------------------------|
| **mem**  | a pointer to allocated memory to reallocate, or NULL. |
| **size** | the new size of the memory.                           |

## Return Value

Returns a pointer to the newly allocated memory, or NULL if allocation
failed.

## Remarks

SDL will always ensure that the passed `size` is greater than 0.

## Thread Safety

It should be safe to call this callback from any thread.

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_realloc](SDL_realloc.html)
- [SDL_GetOriginalMemoryFunctions](SDL_GetOriginalMemoryFunctions.html)
- [SDL_GetMemoryFunctions](SDL_GetMemoryFunctions.html)
- [SDL_SetMemoryFunctions](SDL_SetMemoryFunctions.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryStdinc](CategoryStdinc.html)
