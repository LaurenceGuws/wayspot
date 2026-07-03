# SDL_InsertGPUDebugLabel

Inserts an arbitrary string label into the command buffer callstream.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_InsertGPUDebugLabel(
    SDL_GPUCommandBuffer *command_buffer,
    const char *text);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUCommandBuffer](SDL_GPUCommandBuffer.html) \* | **command_buffer** | a command buffer. |
| const char \* | **text** | a UTF-8 string constant to insert as the label. |

## Remarks

Useful for debugging.

On Direct3D 12, using
[SDL_InsertGPUDebugLabel](SDL_InsertGPUDebugLabel.html) requires
WinPixEventRuntime.dll to be in your PATH or in the same directory as
your executable. See
[here](https://devblogs.microsoft.com/pix/winpixeventruntime/) for
instructions on how to obtain it.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
