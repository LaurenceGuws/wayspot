# SDL_LoadSurface

Load a BMP or PNG image from a file.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Surface * SDL_LoadSurface(const char *file);
```

</div>

## Function Parameters

|               |          |                   |
|---------------|----------|-------------------|
| const char \* | **file** | the file to load. |

## Return Value

([SDL_Surface](SDL_Surface.html) \*) Returns a pointer to a new
[SDL_Surface](SDL_Surface.html) structure or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The new surface should be freed with
[SDL_DestroySurface](SDL_DestroySurface.html)(). Not doing so will
result in a memory leak.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.4.0.

## See Also

- [SDL_DestroySurface](SDL_DestroySurface.html)
- [SDL_LoadSurface_IO](SDL_LoadSurface_IO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
