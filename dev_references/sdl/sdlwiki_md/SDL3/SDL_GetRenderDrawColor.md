# SDL_GetRenderDrawColor

Get the color used for drawing operations (Rect, Line and Clear).

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetRenderDrawColor(SDL_Renderer *renderer, Uint8 *r, Uint8 *g, Uint8 *b, Uint8 *a);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| Uint8 \* | **r** | a pointer filled in with the red value used to draw on the rendering target. |
| Uint8 \* | **g** | a pointer filled in with the green value used to draw on the rendering target. |
| Uint8 \* | **b** | a pointer filled in with the blue value used to draw on the rendering target. |
| Uint8 \* | **a** | a pointer filled in with the alpha value used to draw on the rendering target; usually [`SDL_ALPHA_OPAQUE`](SDL_ALPHA_OPAQUE.html) (255). |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetRenderDrawColorFloat](SDL_GetRenderDrawColorFloat.html)
- [SDL_SetRenderDrawColor](SDL_SetRenderDrawColor.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
