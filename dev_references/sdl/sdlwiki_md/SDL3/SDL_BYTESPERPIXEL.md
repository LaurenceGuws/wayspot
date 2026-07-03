# SDL_BYTESPERPIXEL

A macro to determine an [SDL_PixelFormat](SDL_PixelFormat.html)'s bytes
per pixel.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_BYTESPERPIXEL(format) \
    (SDL_ISPIXELFORMAT_FOURCC(format) ? \
        ((((format) == SDL_PIXELFORMAT_YUY2) || \
          ((format) == SDL_PIXELFORMAT_UYVY) || \
          ((format) == SDL_PIXELFORMAT_YVYU) || \
          ((format) == SDL_PIXELFORMAT_P010)) ? 2 : 1) : (((format) >> 0) & 0xFF))
```

</div>

## Macro Parameters

|            |                                                      |
|------------|------------------------------------------------------|
| **format** | an [SDL_PixelFormat](SDL_PixelFormat.html) to check. |

## Return Value

Returns the bytes-per-pixel of `format`.

## Remarks

Note that this macro double-evaluates its parameter, so do not use
expressions with side-effects here.

FourCC formats do their best here, but many of them don't have a
meaningful measurement of bytes per pixel.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_BITSPERPIXEL](SDL_BITSPERPIXEL.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPixels](CategoryPixels.html)
