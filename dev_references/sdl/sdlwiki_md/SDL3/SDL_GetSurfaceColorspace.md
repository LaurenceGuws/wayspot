# SDL_GetSurfaceColorspace

Get the colorspace used by a surface.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Colorspace SDL_GetSurfaceColorspace(SDL_Surface *surface);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the [SDL_Surface](SDL_Surface.html) structure to query. |

## Return Value

([SDL_Colorspace](SDL_Colorspace.html)) Returns the colorspace used by
the surface, or [SDL_COLORSPACE_UNKNOWN](SDL_COLORSPACE_UNKNOWN.html) if
the surface is NULL.

## Remarks

The colorspace defaults to
[SDL_COLORSPACE_SRGB_LINEAR](SDL_COLORSPACE_SRGB_LINEAR.html) for
floating point formats,
[SDL_COLORSPACE_HDR10](SDL_COLORSPACE_HDR10.html) for 10-bit formats,
[SDL_COLORSPACE_SRGB](SDL_COLORSPACE_SRGB.html) for other RGB surfaces
and [SDL_COLORSPACE_BT709_FULL](SDL_COLORSPACE_BT709_FULL.html) for YUV
textures.

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetSurfaceColorspace](SDL_SetSurfaceColorspace.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
