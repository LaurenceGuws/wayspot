# SDL_DestroyPalette

Free a palette created with
[SDL_CreatePalette](SDL_CreatePalette.html)().

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyPalette(SDL_Palette *palette);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Palette](SDL_Palette.html) \* | **palette** | the [SDL_Palette](SDL_Palette.html) structure to be freed. |

## Thread Safety

It is safe to call this function from any thread, as long as the palette
is not modified or destroyed in another thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreatePalette](SDL_CreatePalette.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryPixels](CategoryPixels.html)
