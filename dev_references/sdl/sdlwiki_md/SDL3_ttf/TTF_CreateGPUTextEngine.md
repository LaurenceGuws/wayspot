###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_CreateGPUTextEngine

Create a text engine for drawing text with the SDL GPU API.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
TTF_TextEngine * TTF_CreateGPUTextEngine(SDL_GPUDevice *device);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| SDL_GPUDevice \* | **device** | the SDL_GPUDevice to use for creating textures and drawing text. |

## Return Value

([TTF_TextEngine](TTF_TextEngine.html) \*) Returns a
[TTF_TextEngine](TTF_TextEngine.html) object or NULL on failure; call
SDL_GetError() for more information.

## Thread Safety

This function should be called on the thread that created the device.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_CreateGPUTextEngineWithProperties](TTF_CreateGPUTextEngineWithProperties.html)
- [TTF_DestroyGPUTextEngine](TTF_DestroyGPUTextEngine.html)
- [TTF_GetGPUTextDrawData](TTF_GetGPUTextDrawData.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
