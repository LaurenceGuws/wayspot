# SDL_CreateGPURenderState

Create custom GPU render state.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GPURenderState * SDL_CreateGPURenderState(SDL_Renderer *renderer, const SDL_GPURenderStateCreateInfo *createinfo);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the renderer to use. |
| const [SDL_GPURenderStateCreateInfo](SDL_GPURenderStateCreateInfo.html) \* | **createinfo** | a struct describing the GPU render state to create. |

## Return Value

([SDL_GPURenderState](SDL_GPURenderState.html) \*) Returns a custom GPU
render state or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should be called on the thread that created the renderer.

## Version

This function is available since SDL 3.4.0.

## See Also

- [SDL_SetGPURenderStateFragmentUniforms](SDL_SetGPURenderStateFragmentUniforms.html)
- [SDL_SetGPURenderState](SDL_SetGPURenderState.html)
- [SDL_DestroyGPURenderState](SDL_DestroyGPURenderState.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
