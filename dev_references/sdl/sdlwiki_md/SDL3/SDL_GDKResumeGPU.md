# SDL_GDKResumeGPU

Call this to resume GPU operation on Xbox when you receive the
[SDL_EVENT_WILL_ENTER_FOREGROUND](SDL_EVENT_WILL_ENTER_FOREGROUND.html)
event.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_GDKResumeGPU(SDL_GPUDevice *device);
```

</div>

## Function Parameters

|                                        |            |                |
|----------------------------------------|------------|----------------|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |

## Remarks

When resuming, this function MUST be called before calling any other
[SDL_GPU](SDL_GPU.html) functions.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AddEventWatch](SDL_AddEventWatch.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
