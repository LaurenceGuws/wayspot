# SDL_SetRenderDrawBlendMode

Set the blend mode used for drawing operations (Fill and Line).

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetRenderDrawBlendMode(SDL_Renderer *renderer, SDL_BlendMode blendMode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| [SDL_BlendMode](SDL_BlendMode.html) | **blendMode** | the [SDL_BlendMode](SDL_BlendMode.html) to use for blending. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

If the blend mode is not supported, the closest supported mode is
chosen.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetRenderDrawBlendMode](SDL_GetRenderDrawBlendMode.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
