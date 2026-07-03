# SDL_GPUTransferBuffer

An opaque handle representing a transfer buffer.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUTransferBuffer SDL_GPUTransferBuffer;
```

</div>

## Remarks

Used for transferring data to and from the device.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUTransferBuffer](SDL_CreateGPUTransferBuffer.html)
- [SDL_MapGPUTransferBuffer](SDL_MapGPUTransferBuffer.html)
- [SDL_UnmapGPUTransferBuffer](SDL_UnmapGPUTransferBuffer.html)
- [SDL_UploadToGPUBuffer](SDL_UploadToGPUBuffer.html)
- [SDL_UploadToGPUTexture](SDL_UploadToGPUTexture.html)
- [SDL_DownloadFromGPUBuffer](SDL_DownloadFromGPUBuffer.html)
- [SDL_DownloadFromGPUTexture](SDL_DownloadFromGPUTexture.html)
- [SDL_ReleaseGPUTransferBuffer](SDL_ReleaseGPUTransferBuffer.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryGPU](CategoryGPU.html)
