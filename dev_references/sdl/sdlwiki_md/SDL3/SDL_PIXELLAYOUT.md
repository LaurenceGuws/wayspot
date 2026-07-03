# SDL_PIXELLAYOUT

A macro to retrieve the layout of an
[SDL_PixelFormat](SDL_PixelFormat.html).

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_PIXELLAYOUT(format)  (((format) >> 16) & 0x0F)
```

</div>

## Macro Parameters

|            |                                                      |
|------------|------------------------------------------------------|
| **format** | an [SDL_PixelFormat](SDL_PixelFormat.html) to check. |

## Return Value

Returns the layout of `format`.

## Remarks

This is usually a value from the
[SDL_PackedLayout](SDL_PackedLayout.html) enumeration, or zero if a
layout doesn't make sense for the format type.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPixels](CategoryPixels.html)
