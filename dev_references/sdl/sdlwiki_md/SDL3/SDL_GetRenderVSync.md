# SDL_GetRenderVSync

Get VSync of the given renderer.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetRenderVSync(SDL_Renderer *renderer, int *vsync);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the renderer to toggle. |
| int \* | **vsync** | an int filled with the current vertical refresh sync interval. See [SDL_SetRenderVSync](SDL_SetRenderVSync.html)() for the meaning of the value. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetRenderVSync](SDL_SetRenderVSync.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
