# SDL_GPUPresentMode

Specifies the timing that will be used to present swapchain textures to
the OS.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_GPUPresentMode
{
    SDL_GPU_PRESENTMODE_VSYNC,
    SDL_GPU_PRESENTMODE_IMMEDIATE,
    SDL_GPU_PRESENTMODE_MAILBOX
} SDL_GPUPresentMode;
```

</div>

## Remarks

VSYNC mode will always be supported. IMMEDIATE and MAILBOX modes may not
be supported on certain systems.

It is recommended to query
[SDL_WindowSupportsGPUPresentMode](SDL_WindowSupportsGPUPresentMode.html)
after claiming the window if you wish to change the present mode to
IMMEDIATE or MAILBOX.

- VSYNC: Waits for vblank before presenting. No tearing is possible. If
  there is a pending image to present, the new image is enqueued for
  presentation. Disallows tearing at the cost of visual latency.
- IMMEDIATE: Immediately presents. Lowest latency option, but tearing
  may occur.
- MAILBOX: Waits for vblank before presenting. No tearing is possible.
  If there is a pending image to present, the pending image is replaced
  by the new image. Similar to VSYNC, but with reduced visual latency.

## Version

This enum is available since SDL 3.2.0.

## See Also

- [SDL_SetGPUSwapchainParameters](SDL_SetGPUSwapchainParameters.html)
- [SDL_WindowSupportsGPUPresentMode](SDL_WindowSupportsGPUPresentMode.html)
- [SDL_WaitAndAcquireGPUSwapchainTexture](SDL_WaitAndAcquireGPUSwapchainTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html), [CategoryGPU](CategoryGPU.html)
