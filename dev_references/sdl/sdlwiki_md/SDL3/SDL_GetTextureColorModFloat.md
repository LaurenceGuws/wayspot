# SDL_GetTextureColorModFloat

Get the additional color value multiplied into render copy operations.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetTextureColorModFloat(SDL_Texture *texture, float *r, float *g, float *b);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the texture to query. |
| float \* | **r** | a pointer filled in with the current red color value. |
| float \* | **g** | a pointer filled in with the current green color value. |
| float \* | **b** | a pointer filled in with the current blue color value. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetTextureAlphaModFloat](SDL_GetTextureAlphaModFloat.html)
- [SDL_GetTextureColorMod](SDL_GetTextureColorMod.html)
- [SDL_SetTextureColorModFloat](SDL_SetTextureColorModFloat.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
