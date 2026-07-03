# SDL_GetCurrentRenderOutputSize

Get the current output size in pixels of a rendering context.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetCurrentRenderOutputSize(SDL_Renderer *renderer, int *w, int *h);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| int \* | **w** | a pointer filled in with the current width. |
| int \* | **h** | a pointer filled in with the current height. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

If a rendering target is active, this will return the size of the
rendering target in pixels, otherwise return the value of
[SDL_GetRenderOutputSize](SDL_GetRenderOutputSize.html)().

Rendering target or not, the output will be adjusted by the current
logical presentation state, dictated by
[SDL_SetRenderLogicalPresentation](SDL_SetRenderLogicalPresentation.html)().

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetRenderOutputSize](SDL_GetRenderOutputSize.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
