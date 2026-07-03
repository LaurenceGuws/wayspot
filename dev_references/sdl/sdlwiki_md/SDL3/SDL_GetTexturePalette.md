# SDL_GetTexturePalette

Get the palette used by a texture.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Palette * SDL_GetTexturePalette(SDL_Texture *texture);
```

</div>

## Function Parameters

|                                    |             |                       |
|------------------------------------|-------------|-----------------------|
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the texture to query. |

## Return Value

([SDL_Palette](SDL_Palette.html) \*) Returns a pointer to the palette
used by the texture, or NULL if there is no palette used.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.4.0.

## See Also

- [SDL_SetTexturePalette](SDL_SetTexturePalette.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
