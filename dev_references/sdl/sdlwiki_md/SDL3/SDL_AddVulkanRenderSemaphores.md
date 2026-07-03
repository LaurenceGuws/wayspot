# SDL_AddVulkanRenderSemaphores

Add a set of synchronization semaphores for the current frame.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_AddVulkanRenderSemaphores(SDL_Renderer *renderer, Uint32 wait_stage_mask, Sint64 wait_semaphore, Sint64 signal_semaphore);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| [Uint32](Uint32.html) | **wait_stage_mask** | the VkPipelineStageFlags for the wait. |
| [Sint64](Sint64.html) | **wait_semaphore** | a VkSempahore to wait on before rendering the current frame, or 0 if not needed. |
| [Sint64](Sint64.html) | **signal_semaphore** | a VkSempahore that SDL will signal when rendering for the current frame is complete, or 0 if not needed. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The Vulkan renderer will wait for `wait_semaphore` before submitting
rendering commands and signal `signal_semaphore` after rendering
commands are complete for this frame.

This should be called each frame that you want semaphore
synchronization. The Vulkan renderer may have multiple frames in flight
on the GPU, so you should have multiple semaphores that are used for
synchronization. Querying
[SDL_PROP_RENDERER_VULKAN_SWAPCHAIN_IMAGE_COUNT_NUMBER](SDL_PROP_RENDERER_VULKAN_SWAPCHAIN_IMAGE_COUNT_NUMBER.html)
will give you the maximum number of semaphores you'll need.

## Thread Safety

It is **NOT** safe to call this function from two threads at once.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
