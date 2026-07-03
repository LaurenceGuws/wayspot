# SDL_Color

A structure that represents a color as RGBA components.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_Color
{
    Uint8 r;
    Uint8 g;
    Uint8 b;
    Uint8 a;
} SDL_Color;
```

</div>

## Remarks

The bits of this structure can be directly reinterpreted as an
integer-packed color which uses the
[SDL_PIXELFORMAT_RGBA32](SDL_PIXELFORMAT_RGBA32.html) format
([SDL_PIXELFORMAT_ABGR8888](SDL_PIXELFORMAT_ABGR8888.html) on
little-endian systems and
[SDL_PIXELFORMAT_RGBA8888](SDL_PIXELFORMAT_RGBA8888.html) on big-endian
systems).

## Version

This struct is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryPixels](CategoryPixels.html)
