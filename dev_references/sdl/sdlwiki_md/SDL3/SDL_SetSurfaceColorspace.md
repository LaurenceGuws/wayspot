# SDL_SetSurfaceColorspace

Set the colorspace used by a surface.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetSurfaceColorspace(SDL_Surface *surface, SDL_Colorspace colorspace);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to update. |
| [SDL_Colorspace](SDL_Colorspace.html) | **colorspace** | an [SDL_Colorspace](SDL_Colorspace.html) value describing the surface colorspace. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Setting the colorspace doesn't change the pixels, only how they are
interpreted in color operations.

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetSurfaceColorspace](SDL_GetSurfaceColorspace.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
