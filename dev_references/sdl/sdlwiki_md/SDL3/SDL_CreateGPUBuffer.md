# SDL_CreateGPUBuffer

Creates a buffer object to be used in graphics or compute workflows.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GPUBuffer * SDL_CreateGPUBuffer(
    SDL_GPUDevice *device,
    const SDL_GPUBufferCreateInfo *createinfo);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU Context. |
| const [SDL_GPUBufferCreateInfo](SDL_GPUBufferCreateInfo.html) \* | **createinfo** | a struct describing the state of the buffer to create. |

## Return Value

([SDL_GPUBuffer](SDL_GPUBuffer.html) \*) Returns a buffer object on
success, or NULL on failure; call [SDL_GetError](SDL_GetError.html)()
for more information.

## Remarks

The contents of this buffer are undefined until data is written to the
buffer.

Note that certain combinations of usage flags are invalid. For example,
a buffer cannot have both the VERTEX and INDEX flags.

If you use a STORAGE flag, the data in the buffer must respect std140
layout conventions. In practical terms this means you must ensure that
vec3 and vec4 fields are 16-byte aligned.

For better understanding of underlying concepts and memory management
with SDL GPU API, you may refer [this blog
post](https://moonside.games/posts/sdl-gpu-concepts-cycling/) .

There are optional properties that can be provided through `props`.
These are the supported properties:

- [`SDL_PROP_GPU_BUFFER_CREATE_NAME_STRING`](SDL_PROP_GPU_BUFFER_CREATE_NAME_STRING.html):
  a name that can be displayed in debugging tools.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_UploadToGPUBuffer](SDL_UploadToGPUBuffer.html)
- [SDL_DownloadFromGPUBuffer](SDL_DownloadFromGPUBuffer.html)
- [SDL_CopyGPUBufferToBuffer](SDL_CopyGPUBufferToBuffer.html)
- [SDL_BindGPUVertexBuffers](SDL_BindGPUVertexBuffers.html)
- [SDL_BindGPUIndexBuffer](SDL_BindGPUIndexBuffer.html)
- [SDL_BindGPUVertexStorageBuffers](SDL_BindGPUVertexStorageBuffers.html)
- [SDL_BindGPUFragmentStorageBuffers](SDL_BindGPUFragmentStorageBuffers.html)
- [SDL_DrawGPUPrimitivesIndirect](SDL_DrawGPUPrimitivesIndirect.html)
- [SDL_DrawGPUIndexedPrimitivesIndirect](SDL_DrawGPUIndexedPrimitivesIndirect.html)
- [SDL_BindGPUComputeStorageBuffers](SDL_BindGPUComputeStorageBuffers.html)
- [SDL_DispatchGPUComputeIndirect](SDL_DispatchGPUComputeIndirect.html)
- [SDL_ReleaseGPUBuffer](SDL_ReleaseGPUBuffer.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
