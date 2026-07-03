# SDL_DestroyGPURenderState

Destroy custom GPU render state.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyGPURenderState(SDL_GPURenderState *state);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPURenderState](SDL_GPURenderState.html) \* | **state** | the state to destroy. |

## Thread Safety

This function should be called on the thread that created the renderer.

## Version

This function is available since SDL 3.4.0.

## See Also

- [SDL_CreateGPURenderState](SDL_CreateGPURenderState.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
