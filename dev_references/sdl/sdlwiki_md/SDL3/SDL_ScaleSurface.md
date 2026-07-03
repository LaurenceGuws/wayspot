# SDL_ScaleSurface

Creates a new surface identical to the existing surface, scaled to the
desired size.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Surface * SDL_ScaleSurface(SDL_Surface *surface, int width, int height, SDL_ScaleMode scaleMode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the surface to duplicate and scale. |
| int | **width** | the width of the new surface. |
| int | **height** | the height of the new surface. |
| [SDL_ScaleMode](SDL_ScaleMode.html) | **scaleMode** | the [SDL_ScaleMode](SDL_ScaleMode.html) to be used. |

## Return Value

([SDL_Surface](SDL_Surface.html) \*) Returns a copy of the surface or
NULL on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

The returned surface should be freed with
[SDL_DestroySurface](SDL_DestroySurface.html)().

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_DestroySurface](SDL_DestroySurface.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
