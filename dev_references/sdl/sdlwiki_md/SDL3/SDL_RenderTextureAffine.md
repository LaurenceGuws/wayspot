# SDL_RenderTextureAffine

Copy a portion of the source texture to the current rendering target,
with affine transform, at subpixel precision.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RenderTextureAffine(SDL_Renderer *renderer, SDL_Texture *texture,
                         const SDL_FRect *srcrect, const SDL_FPoint *origin,
                         const SDL_FPoint *right, const SDL_FPoint *down);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the renderer which should copy parts of a texture. |
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the source texture. |
| const [SDL_FRect](SDL_FRect.html) \* | **srcrect** | a pointer to the source rectangle, or NULL for the entire texture. |
| const [SDL_FPoint](SDL_FPoint.html) \* | **origin** | a pointer to a point indicating where the top-left corner of srcrect should be mapped to, or NULL for the rendering target's origin. |
| const [SDL_FPoint](SDL_FPoint.html) \* | **right** | a pointer to a point indicating where the top-right corner of srcrect should be mapped to, or NULL for the rendering target's top-right corner. |
| const [SDL_FPoint](SDL_FPoint.html) \* | **down** | a pointer to a point indicating where the bottom-left corner of srcrect should be mapped to, or NULL for the rendering target's bottom-left corner. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

You may only call this function from the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_RenderTexture](SDL_RenderTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
