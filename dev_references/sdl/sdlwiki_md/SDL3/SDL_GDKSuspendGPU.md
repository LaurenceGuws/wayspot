# SDL_GDKSuspendGPU

Call this to suspend GPU operation on Xbox when you receive the
[SDL_EVENT_DID_ENTER_BACKGROUND](SDL_EVENT_DID_ENTER_BACKGROUND.html)
event.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_GDKSuspendGPU(SDL_GPUDevice *device);
```

</div>

## Function Parameters

|                                        |            |                |
|----------------------------------------|------------|----------------|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |

## Remarks

Do NOT call any [SDL_GPU](SDL_GPU.html) functions after calling this
function! This must also be called before calling
[SDL_GDKSuspendComplete](SDL_GDKSuspendComplete.html).

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AddEventWatch](SDL_AddEventWatch.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
