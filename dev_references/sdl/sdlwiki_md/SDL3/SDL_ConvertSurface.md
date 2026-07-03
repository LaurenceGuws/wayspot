# SDL_ConvertSurface

Copy an existing surface to a new surface of the specified format.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Surface * SDL_ConvertSurface(SDL_Surface *surface, SDL_PixelFormat format);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Surface](SDL_Surface.html) \* | **surface** | the existing [SDL_Surface](SDL_Surface.html) structure to convert. |
| [SDL_PixelFormat](SDL_PixelFormat.html) | **format** | the new pixel format. |

## Return Value

([SDL_Surface](SDL_Surface.html) \*) Returns the new
[SDL_Surface](SDL_Surface.html) structure that is created or NULL on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function is used to optimize images for faster *repeat* blitting.
This is accomplished by converting the original and storing the result
as a new surface. The new, optimized surface can then be used as the
source for future blits, making them faster.

If you are converting to an indexed surface and want to map colors to a
palette, you can use
[SDL_ConvertSurfaceAndColorspace](SDL_ConvertSurfaceAndColorspace.html)()
instead.

If the original surface has alternate images, the new surface will have
a reference to them as well.

## Thread Safety

This function can be called on different threads with different
surfaces.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
SDL_Surface *input;
SDL_Surface *output = SDL_ConvertSurface(input, SDL_PIXELFORMAT_RGBA32);
```

</div>

## See Also

- [SDL_ConvertSurfaceAndColorspace](SDL_ConvertSurfaceAndColorspace.html)
- [SDL_DestroySurface](SDL_DestroySurface.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySurface](CategorySurface.html)
