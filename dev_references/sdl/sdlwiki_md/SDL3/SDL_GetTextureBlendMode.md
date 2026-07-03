# SDL_GetTextureBlendMode

Get the blend mode used for texture copy operations.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetTextureBlendMode(SDL_Texture *texture, SDL_BlendMode *blendMode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the texture to query. |
| [SDL_BlendMode](SDL_BlendMode.html) \* | **blendMode** | a pointer filled in with the current [SDL_BlendMode](SDL_BlendMode.html). |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetTextureBlendMode](SDL_SetTextureBlendMode.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
