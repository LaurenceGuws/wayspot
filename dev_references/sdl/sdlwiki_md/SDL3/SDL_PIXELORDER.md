# SDL_PIXELORDER

A macro to retrieve the order of an
[SDL_PixelFormat](SDL_PixelFormat.html).

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_PIXELORDER(format)   (((format) >> 20) & 0x0F)
```

</div>

## Macro Parameters

|            |                                                      |
|------------|------------------------------------------------------|
| **format** | an [SDL_PixelFormat](SDL_PixelFormat.html) to check. |

## Return Value

Returns the order of `format`.

## Remarks

This is usually a value from the
[SDL_BitmapOrder](SDL_BitmapOrder.html),
[SDL_PackedOrder](SDL_PackedOrder.html), or
[SDL_ArrayOrder](SDL_ArrayOrder.html) enumerations, depending on the
format type.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPixels](CategoryPixels.html)
