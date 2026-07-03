# SDL_DEFINE_PIXELFOURCC

A macro for defining custom FourCC pixel formats.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_DEFINE_PIXELFOURCC(A, B, C, D) SDL_FOURCC(A, B, C, D)
```

</div>

## Macro Parameters

|       |                                          |
|-------|------------------------------------------|
| **A** | the first character of the FourCC code.  |
| **B** | the second character of the FourCC code. |
| **C** | the third character of the FourCC code.  |
| **D** | the fourth character of the FourCC code. |

## Return Value

Returns a format value in the style of
[SDL_PixelFormat](SDL_PixelFormat.html).

## Remarks

For example, defining [SDL_PIXELFORMAT_YV12](SDL_PIXELFORMAT_YV12.html)
looks like this:

<div id="cb2" class="sourceCode">

``` sourceCode
SDL_DEFINE_PIXELFOURCC('Y', 'V', '1', '2')
```

</div>

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPixels](CategoryPixels.html)
