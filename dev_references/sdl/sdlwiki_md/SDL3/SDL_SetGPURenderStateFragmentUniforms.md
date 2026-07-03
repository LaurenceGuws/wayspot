# SDL_SetGPURenderStateFragmentUniforms

Set fragment shader uniform variables in a custom GPU render state.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetGPURenderStateFragmentUniforms(SDL_GPURenderState *state, Uint32 slot_index, const void *data, Uint32 length);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPURenderState](SDL_GPURenderState.html) \* | **state** | the state to modify. |
| [Uint32](Uint32.html) | **slot_index** | the fragment uniform slot to push data to. |
| const void \* | **data** | client data to write. |
| [Uint32](Uint32.html) | **length** | the length of the data to write. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The data is copied and will be pushed using
[SDL_PushGPUFragmentUniformData](SDL_PushGPUFragmentUniformData.html)()
during draw call execution.

## Thread Safety

This function should be called on the thread that created the renderer.

## Version

This function is available since SDL 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
