# SDL_CreateGPUTransferBuffer

Creates a transfer buffer to be used when uploading to or downloading
from graphics resources.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GPUTransferBuffer * SDL_CreateGPUTransferBuffer(
    SDL_GPUDevice *device,
    const SDL_GPUTransferBufferCreateInfo *createinfo);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU Context. |
| const [SDL_GPUTransferBufferCreateInfo](SDL_GPUTransferBufferCreateInfo.html) \* | **createinfo** | a struct describing the state of the transfer buffer to create. |

## Return Value

([SDL_GPUTransferBuffer](SDL_GPUTransferBuffer.html) \*) Returns a
transfer buffer on success, or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Download buffers can be particularly expensive to create, so it is good
practice to reuse them if data will be downloaded regularly.

There are optional properties that can be provided through `props`.
These are the supported properties:

- [`SDL_PROP_GPU_TRANSFERBUFFER_CREATE_NAME_STRING`](SDL_PROP_GPU_TRANSFERBUFFER_CREATE_NAME_STRING.html):
  a name that can be displayed in debugging tools.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_UploadToGPUBuffer](SDL_UploadToGPUBuffer.html)
- [SDL_DownloadFromGPUBuffer](SDL_DownloadFromGPUBuffer.html)
- [SDL_UploadToGPUTexture](SDL_UploadToGPUTexture.html)
- [SDL_DownloadFromGPUTexture](SDL_DownloadFromGPUTexture.html)
- [SDL_ReleaseGPUTransferBuffer](SDL_ReleaseGPUTransferBuffer.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
