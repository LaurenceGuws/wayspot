# SDL_Palette

A set of indexed colors representing a palette.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_Palette
{
    int ncolors;        /**< number of elements in `colors`. */
    SDL_Color *colors;  /**< an array of colors, `ncolors` long. */
    Uint32 version;     /**< internal use only, do not touch. */
    int refcount;       /**< internal use only, do not touch. */
} SDL_Palette;
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_SetPaletteColors](SDL_SetPaletteColors.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryPixels](CategoryPixels.html)
