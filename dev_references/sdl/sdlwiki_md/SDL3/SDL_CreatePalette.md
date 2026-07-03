# SDL_CreatePalette

Create a palette structure with the specified number of color entries.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Palette * SDL_CreatePalette(int ncolors);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int | **ncolors** | represents the number of color entries in the color palette. |

## Return Value

([SDL_Palette](SDL_Palette.html) \*) Returns a new
[SDL_Palette](SDL_Palette.html) structure on success or NULL on failure
(e.g. if there wasn't enough memory); call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The palette entries are initialized to white.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_DestroyPalette](SDL_DestroyPalette.html)
- [SDL_SetPaletteColors](SDL_SetPaletteColors.html)
- [SDL_SetSurfacePalette](SDL_SetSurfacePalette.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryPixels](CategoryPixels.html)
