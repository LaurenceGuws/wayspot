# SDL_ReleaseGPUFence

Releases a fence obtained from
[SDL_SubmitGPUCommandBufferAndAcquireFence](SDL_SubmitGPUCommandBufferAndAcquireFence.html).

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_ReleaseGPUFence(
    SDL_GPUDevice *device,
    SDL_GPUFence *fence);
```

</div>

## Function Parameters

|                                        |            |                |
|----------------------------------------|------------|----------------|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| [SDL_GPUFence](SDL_GPUFence.html) \*   | **fence**  | a fence.       |

## Remarks

You must not reference the fence after calling this function.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SubmitGPUCommandBufferAndAcquireFence](SDL_SubmitGPUCommandBufferAndAcquireFence.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
