# SDL_SetTextureColorMod

Set an additional color value multiplied into render copy operations.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetTextureColorMod(SDL_Texture *texture, Uint8 r, Uint8 g, Uint8 b);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the texture to update. |
| Uint8 | **r** | the red color value multiplied into copy operations. |
| Uint8 | **g** | the green color value multiplied into copy operations. |
| Uint8 | **b** | the blue color value multiplied into copy operations. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

When this texture is rendered, during the copy operation each source
color channel is modulated by the appropriate color value according to
the following formula:

`srcC = srcC * (color / 255)`

Color modulation is not always supported by the renderer; it will return
false if color modulation is not supported.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetTextureColorMod](SDL_GetTextureColorMod.html)
- [SDL_SetTextureAlphaMod](SDL_SetTextureAlphaMod.html)
- [SDL_SetTextureColorModFloat](SDL_SetTextureColorModFloat.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
