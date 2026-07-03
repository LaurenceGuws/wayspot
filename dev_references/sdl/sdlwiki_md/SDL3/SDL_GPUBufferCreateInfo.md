# SDL_GPUBufferCreateInfo

A structure specifying the parameters of a buffer.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUBufferCreateInfo
{
    SDL_GPUBufferUsageFlags usage;  /**< How the buffer is intended to be used by the client. */
    Uint32 size;                    /**< The size in bytes of the buffer. */

    SDL_PropertiesID props;         /**< A properties ID for extensions. Should be 0 if no extensions are needed. */
} SDL_GPUBufferCreateInfo;
```

</div>

## Remarks

Usage flags can be bitwise OR'd together for combinations of usages.
Note that certain combinations are invalid, for example VERTEX and
INDEX.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUBuffer](SDL_CreateGPUBuffer.html)
- [SDL_GPUBufferUsageFlags](SDL_GPUBufferUsageFlags.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
