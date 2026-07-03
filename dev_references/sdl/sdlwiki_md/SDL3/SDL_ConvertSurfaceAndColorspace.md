# SDL_ConvertSurfaceAndColorspace

Copy an existing surface to a new surface of the specified format and
colorspace.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Surface * SDL_ConvertSurfaceAndColorspace(SDL_Surface *surface, SDL_PixelFormat format, SDL_Palette *palette, SDL_Colorspace colorspace, SDL_PropertiesID props);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the existing [SDL_Surface](SDL_Surface.html) structure to convert. |
| [SDL_PixelFormat](SDL_PixelFormat.html) | **format** | the new pixel format. |
| [SDL_Palette](SDL_Palette.html) \* | **palette** | an optional palette to use for indexed formats, may be NULL. |
| [SDL_Colorspace](SDL_Colorspace.html) | **colorspace** | the new colorspace. |
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | an [SDL_PropertiesID](SDL_PropertiesID.html) with additional color properties, or 0. |

## Return Value

([SDL_Surface](SDL_Surface.html) \*) Returns the new
[SDL_Surface](SDL_Surface.html) structure that is created or NULL on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function converts an existing surface to a new format and
colorspace and returns the new surface. This will perform any pixel
format and colorspace conversion needed.

If the original surface has alternate images, the new surface will have
a reference to them as well.

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_ConvertSurface](SDL_ConvertSurface.html)
- [SDL_DestroySurface](SDL_DestroySurface.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
