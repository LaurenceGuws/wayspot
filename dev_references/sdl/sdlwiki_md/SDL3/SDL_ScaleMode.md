# SDL_ScaleMode

The scaling mode.

## Header File

Defined in
[\<SDL3/SDL_surface.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_surface.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_ScaleMode
{
    SDL_SCALEMODE_INVALID = -1,
    SDL_SCALEMODE_NEAREST,  /**< nearest pixel sampling */
    SDL_SCALEMODE_LINEAR,   /**< linear filtering */
    SDL_SCALEMODE_PIXELART  /**< nearest pixel sampling with improved scaling for pixel art, available since SDL 3.4.0 */
} SDL_ScaleMode;
```

</div>

## Version

This enum is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html),
[CategorySurface](CategorySurface.html)
