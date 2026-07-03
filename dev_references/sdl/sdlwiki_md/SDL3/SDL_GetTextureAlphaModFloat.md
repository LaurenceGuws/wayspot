# SDL_GetTextureAlphaModFloat

Get the additional alpha value multiplied into render copy operations.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetTextureAlphaModFloat(SDL_Texture *texture, float *alpha);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the texture to query. |
| float \* | **alpha** | a pointer filled in with the current alpha value. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetTextureAlphaMod](SDL_GetTextureAlphaMod.html)
- [SDL_GetTextureColorModFloat](SDL_GetTextureColorModFloat.html)
- [SDL_SetTextureAlphaModFloat](SDL_SetTextureAlphaModFloat.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
