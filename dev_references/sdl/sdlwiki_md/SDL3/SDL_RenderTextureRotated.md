# SDL_RenderTextureRotated

Copy a portion of the source texture to the current rendering target,
with rotation and flipping, at subpixel precision.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RenderTextureRotated(SDL_Renderer *renderer, SDL_Texture *texture,
                         const SDL_FRect *srcrect, const SDL_FRect *dstrect,
                         double angle, const SDL_FPoint *center,
                         SDL_FlipMode flip);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the renderer which should copy parts of a texture. |
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the source texture. |
| const [SDL_FRect](SDL_FRect.html) \* | **srcrect** | a pointer to the source rectangle, or NULL for the entire texture. |
| const [SDL_FRect](SDL_FRect.html) \* | **dstrect** | a pointer to the destination rectangle, or NULL for the entire rendering target. |
| double | **angle** | an angle in degrees that indicates the rotation that will be applied to dstrect, rotating it in a clockwise direction. |
| const [SDL_FPoint](SDL_FPoint.html) \* | **center** | a pointer to a point indicating the point around which dstrect will be rotated (if NULL, rotation will be done around dstrect.w/2, dstrect.h/2). |
| [SDL_FlipMode](SDL_FlipMode.html) | **flip** | an [SDL_FlipMode](SDL_FlipMode.html) value stating which flipping actions should be performed on the texture. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_RenderTexture](SDL_RenderTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
