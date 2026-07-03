# SDL_SavePNG_IO

Save a surface to a seekable SDL data stream in PNG format.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SavePNG_IO(SDL_Surface *surface, SDL_IOStream *dst, bool closeio);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure containing the image to be saved. |
| [SDL_IOStream](SDL_IOStream.html) \* | **dst** | a data stream to save to. |
| bool | **closeio** | if true, calls [SDL_CloseIO](SDL_CloseIO.html)() on `dst` before returning, even in the case of an error. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.4.0.

## See Also

- [SDL_LoadPNG_IO](SDL_LoadPNG_IO.html)
- [SDL_SavePNG](SDL_SavePNG.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
