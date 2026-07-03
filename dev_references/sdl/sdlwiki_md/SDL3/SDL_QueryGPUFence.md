# SDL_QueryGPUFence

Checks the status of a fence.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_QueryGPUFence(
    SDL_GPUDevice *device,
    SDL_GPUFence *fence);
```

</div>

## Function Parameters

|                                        |            |                |
|----------------------------------------|------------|----------------|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| [SDL_GPUFence](SDL_GPUFence.html) \*   | **fence**  | a fence.       |

## Return Value

(bool) Returns true if the fence is signaled, false if it is not.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SubmitGPUCommandBufferAndAcquireFence](SDL_SubmitGPUCommandBufferAndAcquireFence.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
