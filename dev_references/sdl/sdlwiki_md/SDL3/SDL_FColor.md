# SDL_FColor

The bits of this structure can be directly reinterpreted as a
float-packed color which uses the
[SDL_PIXELFORMAT_RGBA128_FLOAT](SDL_PIXELFORMAT_RGBA128_FLOAT.html)
format

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_FColor
{
    float r;
    float g;
    float b;
    float a;
} SDL_FColor;
```

</div>

## Version

This struct is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryPixels](CategoryPixels.html)
