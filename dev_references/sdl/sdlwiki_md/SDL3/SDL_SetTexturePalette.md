# SDL_SetTexturePalette

Set the palette used by a texture.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetTexturePalette(SDL_Texture *texture, SDL_Palette *palette);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the texture to update. |
| [SDL_Palette](SDL_Palette.html) \* | **palette** | the [SDL_Palette](SDL_Palette.html) structure to use. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Setting the palette keeps an internal reference to the palette, which
can be safely destroyed afterwards.

A single palette can be shared with many textures.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.4.0.

## See Also

- [SDL_CreatePalette](SDL_CreatePalette.html)
- [SDL_GetTexturePalette](SDL_GetTexturePalette.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
