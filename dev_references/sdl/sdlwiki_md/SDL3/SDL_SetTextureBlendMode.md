# SDL_SetTextureBlendMode

Set the blend mode for a texture, used by
[SDL_RenderTexture](SDL_RenderTexture.html)().

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetTextureBlendMode(SDL_Texture *texture, SDL_BlendMode blendMode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the texture to update. |
| [SDL_BlendMode](SDL_BlendMode.html) | **blendMode** | the [SDL_BlendMode](SDL_BlendMode.html) to use for texture blending. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

If the blend mode is not supported, the closest supported mode is chosen
and this function returns false.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetTextureBlendMode](SDL_GetTextureBlendMode.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
