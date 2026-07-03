# SDL_WaitForGPUFences

Blocks the thread until the given fences are signaled.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_WaitForGPUFences(
    SDL_GPUDevice *device,
    bool wait_all,
    SDL_GPUFence *const *fences,
    Uint32 num_fences);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| bool | **wait_all** | if 0, wait for any fence to be signaled, if 1, wait for all fences to be signaled. |
| [SDL_GPUFence](SDL_GPUFence.html) \*const \* | **fences** | an array of fences to wait on. |
| [Uint32](Uint32.html) | **num_fences** | the number of fences in the fences array. |

## Return Value

(bool) Returns true on success, false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SubmitGPUCommandBufferAndAcquireFence](SDL_SubmitGPUCommandBufferAndAcquireFence.html)
- [SDL_WaitForGPUIdle](SDL_WaitForGPUIdle.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
