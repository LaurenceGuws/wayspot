# SDL_RenderTexture

Copy a portion of the texture to the current rendering target at
subpixel precision.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RenderTexture(SDL_Renderer *renderer, SDL_Texture *texture, const SDL_FRect *srcrect, const SDL_FRect *dstrect);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the renderer which should copy parts of a texture. |
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the source texture. |
| const [SDL_FRect](SDL_FRect.html) \* | **srcrect** | a pointer to the source rectangle, or NULL for the entire texture. |
| const [SDL_FRect](SDL_FRect.html) \* | **dstrect** | a pointer to the destination rectangle, or NULL for the entire rendering target. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_RenderTextureRotated](SDL_RenderTextureRotated.html)
- [SDL_RenderTextureTiled](SDL_RenderTextureTiled.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
