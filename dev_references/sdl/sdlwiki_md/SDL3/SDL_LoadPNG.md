# SDL_LoadPNG

Load a PNG image from a file.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Surface * SDL_LoadPNG(const char *file);
```

</div>

## Function Parameters

|               |          |                       |
|---------------|----------|-----------------------|
| const char \* | **file** | the PNG file to load. |

## Return Value

([SDL_Surface](SDL_Surface.html) \*) Returns a pointer to a new
[SDL_Surface](SDL_Surface.html) structure or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This is intended as a convenience function for loading images from
trusted sources. If you want to load arbitrary images you should use
libpng or another image loading library designed with security in mind.

The new surface should be freed with
[SDL_DestroySurface](SDL_DestroySurface.html)(). Not doing so will
result in a memory leak.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.4.0.

## See Also

- [SDL_DestroySurface](SDL_DestroySurface.html)
- [SDL_LoadPNG_IO](SDL_LoadPNG_IO.html)
- [SDL_SavePNG](SDL_SavePNG.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
