# SDL_ISPIXELFORMAT_ALPHA

A macro to determine if an [SDL_PixelFormat](SDL_PixelFormat.html) has
an alpha channel.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_ISPIXELFORMAT_ALPHA(format)   \
    ((SDL_ISPIXELFORMAT_PACKED(format) && \
      ((SDL_PIXELORDER(format) == SDL_PACKEDORDER_ARGB) || \
       (SDL_PIXELORDER(format) == SDL_PACKEDORDER_RGBA) || \
       (SDL_PIXELORDER(format) == SDL_PACKEDORDER_ABGR) || \
       (SDL_PIXELORDER(format) == SDL_PACKEDORDER_BGRA))) || \
     (SDL_ISPIXELFORMAT_ARRAY(format) && \
      ((SDL_PIXELORDER(format) == SDL_ARRAYORDER_ARGB) || \
       (SDL_PIXELORDER(format) == SDL_ARRAYORDER_RGBA) || \
       (SDL_PIXELORDER(format) == SDL_ARRAYORDER_ABGR) || \
       (SDL_PIXELORDER(format) == SDL_ARRAYORDER_BGRA))))
```

</div>

## Macro Parameters

|            |                                                      |
|------------|------------------------------------------------------|
| **format** | an [SDL_PixelFormat](SDL_PixelFormat.html) to check. |

## Return Value

Returns true if the format has alpha, false otherwise.

## Remarks

Note that this macro double-evaluates its parameter, so do not use
expressions with side-effects here.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPixels](CategoryPixels.html)
