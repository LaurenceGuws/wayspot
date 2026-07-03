# SDL_PIXELFLAG

A macro to retrieve the flags of an
[SDL_PixelFormat](SDL_PixelFormat.html).

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_PIXELFLAG(format)    (((format) >> 28) & 0x0F)
```

</div>

## Macro Parameters

|            |                                                      |
|------------|------------------------------------------------------|
| **format** | an [SDL_PixelFormat](SDL_PixelFormat.html) to check. |

## Return Value

Returns the flags of `format`.

## Remarks

This macro is generally not needed directly by an app, which should use
specific tests, like
[SDL_ISPIXELFORMAT_FOURCC](SDL_ISPIXELFORMAT_FOURCC.html), instead.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPixels](CategoryPixels.html)
