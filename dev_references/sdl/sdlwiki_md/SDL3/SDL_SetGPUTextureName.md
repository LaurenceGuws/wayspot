# SDL_SetGPUTextureName

Sets an arbitrary string constant to label a texture.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SetGPUTextureName(
    SDL_GPUDevice *device,
    SDL_GPUTexture *texture,
    const char *text);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU Context. |
| [SDL_GPUTexture](SDL_GPUTexture.html) \* | **texture** | a texture to attach the name to. |
| const char \* | **text** | a UTF-8 string constant to mark as the name of the texture. |

## Remarks

You should use
[SDL_PROP_GPU_TEXTURE_CREATE_NAME_STRING](SDL_PROP_GPU_TEXTURE_CREATE_NAME_STRING.html)
with [SDL_CreateGPUTexture](SDL_CreateGPUTexture.html) instead of this
function to avoid thread safety issues.

## Thread Safety

This function is not thread safe, you must make sure the texture is not
simultaneously used by any other thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUTexture](SDL_CreateGPUTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
