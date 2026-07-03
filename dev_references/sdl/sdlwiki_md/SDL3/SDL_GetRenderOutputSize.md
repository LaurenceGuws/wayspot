# SDL_GetRenderOutputSize

Get the output size in pixels of a rendering context.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetRenderOutputSize(SDL_Renderer *renderer, int *w, int *h);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| int \* | **w** | a pointer filled in with the width in pixels. |
| int \* | **h** | a pointer filled in with the height in pixels. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This returns the true output size in pixels, ignoring any render targets
or logical size and presentation.

For the output size of the current rendering target, with logical size
adjustments, use
[SDL_GetCurrentRenderOutputSize](SDL_GetCurrentRenderOutputSize.html)()
instead.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetCurrentRenderOutputSize](SDL_GetCurrentRenderOutputSize.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
