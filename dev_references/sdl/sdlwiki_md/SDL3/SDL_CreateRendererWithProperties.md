# SDL_CreateRendererWithProperties

Create a 2D rendering context for a window, with the specified
properties.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Renderer * SDL_CreateRendererWithProperties(SDL_PropertiesID props);
```

</div>

## Function Parameters

|                                           |           |                        |
|-------------------------------------------|-----------|------------------------|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to use. |

## Return Value

([SDL_Renderer](SDL_Renderer.html) \*) Returns a valid rendering context
or NULL if there was an error; call [SDL_GetError](SDL_GetError.html)()
for more information.

## Remarks

These are the supported properties:

- [`SDL_PROP_RENDERER_CREATE_NAME_STRING`](SDL_PROP_RENDERER_CREATE_NAME_STRING.html):
  the name of the rendering driver to use, if a specific one is desired
- [`SDL_PROP_RENDERER_CREATE_WINDOW_POINTER`](SDL_PROP_RENDERER_CREATE_WINDOW_POINTER.html):
  the window where rendering is displayed, required if this isn't a
  software renderer using a surface
- [`SDL_PROP_RENDERER_CREATE_SURFACE_POINTER`](SDL_PROP_RENDERER_CREATE_SURFACE_POINTER.html):
  the surface where rendering is displayed, if you want a software
  renderer without a window
- [`SDL_PROP_RENDERER_CREATE_OUTPUT_COLORSPACE_NUMBER`](SDL_PROP_RENDERER_CREATE_OUTPUT_COLORSPACE_NUMBER.html):
  an [SDL_Colorspace](SDL_Colorspace.html) value describing the
  colorspace for output to the display, defaults to
  [SDL_COLORSPACE_SRGB](SDL_COLORSPACE_SRGB.html). The direct3d11,
  direct3d12, and metal renderers support
  [SDL_COLORSPACE_SRGB_LINEAR](SDL_COLORSPACE_SRGB_LINEAR.html), which
  is a linear color space and supports HDR output. If you select
  [SDL_COLORSPACE_SRGB_LINEAR](SDL_COLORSPACE_SRGB_LINEAR.html), drawing
  still uses the sRGB colorspace, but values can go beyond 1.0 and float
  (linear) format textures can be used for HDR content.
- [`SDL_PROP_RENDERER_CREATE_PRESENT_VSYNC_NUMBER`](SDL_PROP_RENDERER_CREATE_PRESENT_VSYNC_NUMBER.html):
  non-zero if you want present synchronized with the refresh rate. This
  property can take any value that is supported by
  [SDL_SetRenderVSync](SDL_SetRenderVSync.html)() for the renderer.

With the SDL GPU renderer (since SDL 3.4.0):

- [`SDL_PROP_RENDERER_CREATE_GPU_DEVICE_POINTER`](SDL_PROP_RENDERER_CREATE_GPU_DEVICE_POINTER.html):
  the device to use with the renderer, optional.
- [`SDL_PROP_RENDERER_CREATE_GPU_SHADERS_SPIRV_BOOLEAN`](SDL_PROP_RENDERER_CREATE_GPU_SHADERS_SPIRV_BOOLEAN.html):
  the app is able to provide SPIR-V shaders to
  [SDL_GPURenderState](SDL_GPURenderState.html), optional.
- [`SDL_PROP_RENDERER_CREATE_GPU_SHADERS_DXIL_BOOLEAN`](SDL_PROP_RENDERER_CREATE_GPU_SHADERS_DXIL_BOOLEAN.html):
  the app is able to provide DXIL shaders to
  [SDL_GPURenderState](SDL_GPURenderState.html), optional.
- [`SDL_PROP_RENDERER_CREATE_GPU_SHADERS_MSL_BOOLEAN`](SDL_PROP_RENDERER_CREATE_GPU_SHADERS_MSL_BOOLEAN.html):
  the app is able to provide MSL shaders to
  [SDL_GPURenderState](SDL_GPURenderState.html), optional.

With the vulkan renderer:

- [`SDL_PROP_RENDERER_CREATE_VULKAN_INSTANCE_POINTER`](SDL_PROP_RENDERER_CREATE_VULKAN_INSTANCE_POINTER.html):
  the VkInstance to use with the renderer, optional.
- [`SDL_PROP_RENDERER_CREATE_VULKAN_SURFACE_NUMBER`](SDL_PROP_RENDERER_CREATE_VULKAN_SURFACE_NUMBER.html):
  the VkSurfaceKHR to use with the renderer, optional.
- [`SDL_PROP_RENDERER_CREATE_VULKAN_PHYSICAL_DEVICE_POINTER`](SDL_PROP_RENDERER_CREATE_VULKAN_PHYSICAL_DEVICE_POINTER.html):
  the VkPhysicalDevice to use with the renderer, optional.
- [`SDL_PROP_RENDERER_CREATE_VULKAN_DEVICE_POINTER`](SDL_PROP_RENDERER_CREATE_VULKAN_DEVICE_POINTER.html):
  the VkDevice to use with the renderer, optional.
- [`SDL_PROP_RENDERER_CREATE_VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER`](SDL_PROP_RENDERER_CREATE_VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER.html):
  the queue family index used for rendering.
- [`SDL_PROP_RENDERER_CREATE_VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER`](SDL_PROP_RENDERER_CREATE_VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER.html):
  the queue family index used for presentation.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateProperties](SDL_CreateProperties.html)
- [SDL_CreateRenderer](SDL_CreateRenderer.html)
- [SDL_CreateSoftwareRenderer](SDL_CreateSoftwareRenderer.html)
- [SDL_DestroyRenderer](SDL_DestroyRenderer.html)
- [SDL_GetRendererName](SDL_GetRendererName.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
