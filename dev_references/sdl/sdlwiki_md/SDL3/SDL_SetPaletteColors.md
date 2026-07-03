# SDL_SetPaletteColors

Set a range of colors in a palette.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetPaletteColors(SDL_Palette *palette, const SDL_Color *colors, int firstcolor, int ncolors);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Palette](SDL_Palette.html) \* | **palette** | the [SDL_Palette](SDL_Palette.html) structure to modify. |
| const [SDL_Color](SDL_Color.html) \* | **colors** | an array of [SDL_Color](SDL_Color.html) structures to copy into the palette. |
| int | **firstcolor** | the index of the first palette entry to modify. |
| int | **ncolors** | the number of entries to modify. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread, as long as the palette
is not modified or destroyed in another thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryPixels](CategoryPixels.html)
