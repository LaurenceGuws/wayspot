# SDL_RenderTextureTiled

Tile a portion of the texture to the current rendering target at
subpixel precision.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RenderTextureTiled(SDL_Renderer *renderer, SDL_Texture *texture, const SDL_FRect *srcrect, float scale, const SDL_FRect *dstrect);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the renderer which should copy parts of a texture. |
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the source texture. |
| const [SDL_FRect](SDL_FRect.html) \* | **srcrect** | a pointer to the source rectangle, or NULL for the entire texture. |
| float | **scale** | the scale used to transform srcrect into the destination rectangle, e.g. a 32x32 texture with a scale of 2 would fill 64x64 tiles. |
| const [SDL_FRect](SDL_FRect.html) \* | **dstrect** | a pointer to the destination rectangle, or NULL for the entire rendering target. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The pixels in `srcrect` will be repeated as many times as needed to
completely fill `dstrect`.

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
