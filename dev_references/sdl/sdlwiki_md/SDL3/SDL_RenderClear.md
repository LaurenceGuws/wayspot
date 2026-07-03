# SDL_RenderClear

Clear the current rendering target with the drawing color.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RenderClear(SDL_Renderer *renderer);
```

</div>

## Function Parameters

|                                      |              |                        |
|--------------------------------------|--------------|------------------------|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function clears the entire rendering target, ignoring the viewport
and the clip rectangle. Note, that clearing will also set/fill all
pixels of the rendering target to current renderer draw color, so make
sure to invoke [SDL_SetRenderDrawColor](SDL_SetRenderDrawColor.html)()
when needed.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetRenderDrawColor](SDL_SetRenderDrawColor.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
