# SDL_SetRenderDrawColor

Set the color used for drawing operations.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetRenderDrawColor(SDL_Renderer *renderer, Uint8 r, Uint8 g, Uint8 b, Uint8 a);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| Uint8 | **r** | the red value used to draw on the rendering target. |
| Uint8 | **g** | the green value used to draw on the rendering target. |
| Uint8 | **b** | the blue value used to draw on the rendering target. |
| Uint8 | **a** | the alpha value used to draw on the rendering target; usually [`SDL_ALPHA_OPAQUE`](SDL_ALPHA_OPAQUE.html) (255). Use [SDL_SetRenderDrawBlendMode](SDL_SetRenderDrawBlendMode.html) to specify how the alpha channel is used. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Set the color for drawing or filling rectangles, lines, and points, and
for [SDL_RenderClear](SDL_RenderClear.html)().

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetRenderDrawColor](SDL_GetRenderDrawColor.html)
- [SDL_SetRenderDrawColorFloat](SDL_SetRenderDrawColorFloat.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
