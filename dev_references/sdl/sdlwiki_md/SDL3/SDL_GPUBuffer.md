# SDL_GPUBuffer

An opaque handle representing a buffer.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUBuffer SDL_GPUBuffer;
```

</div>

## Remarks

Used for vertices, indices, indirect draw commands, and general compute
data.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUBuffer](SDL_CreateGPUBuffer.html)
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
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryGPU](CategoryGPU.html)
