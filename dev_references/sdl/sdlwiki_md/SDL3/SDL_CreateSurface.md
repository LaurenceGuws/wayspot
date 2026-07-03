# SDL_CreateSurface

Allocate a new surface with a specific pixel format.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Surface * SDL_CreateSurface(int width, int height, SDL_PixelFormat format);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int | **width** | the width of the surface. |
| int | **height** | the height of the surface. |
| [SDL_PixelFormat](SDL_PixelFormat.html) | **format** | the [SDL_PixelFormat](SDL_PixelFormat.html) for the new surface's pixel format. |

## Return Value

([SDL_Surface](SDL_Surface.html) \*) Returns the new
[SDL_Surface](SDL_Surface.html) structure that is created or NULL on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The pixels of the new surface are initialized to zero.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateSurfaceFrom](SDL_CreateSurfaceFrom.html)
- [SDL_DestroySurface](SDL_DestroySurface.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
