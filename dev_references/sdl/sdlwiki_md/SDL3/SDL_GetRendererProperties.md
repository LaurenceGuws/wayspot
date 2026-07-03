# SDL_GetRendererProperties

Get the properties associated with a renderer.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PropertiesID SDL_GetRendererProperties(SDL_Renderer *renderer);
```

</div>

## Function Parameters

|                                      |              |                        |
|--------------------------------------|--------------|------------------------|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |

## Return Value

([SDL_PropertiesID](SDL_PropertiesID.html)) Returns a valid property ID
on success or 0 on failure; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Remarks

The following read-only properties are provided by SDL:

- [`SDL_PROP_RENDERER_NAME_STRING`](SDL_PROP_RENDERER_NAME_STRING.html):
  the name of the rendering driver
- [`SDL_PROP_RENDERER_WINDOW_POINTER`](SDL_PROP_RENDERER_WINDOW_POINTER.html):
  the window where rendering is displayed, if any
- [`SDL_PROP_RENDERER_SURFACE_POINTER`](SDL_PROP_RENDERER_SURFACE_POINTER.html):
  the surface where rendering is displayed, if this is a software
  renderer without a window
- [`SDL_PROP_RENDERER_VSYNC_NUMBER`](SDL_PROP_RENDERER_VSYNC_NUMBER.html):
  the current vsync setting
- [`SDL_PROP_RENDERER_MAX_TEXTURE_SIZE_NUMBER`](SDL_PROP_RENDERER_MAX_TEXTURE_SIZE_NUMBER.html):
  the maximum texture width and height
- [`SDL_PROP_RENDERER_TEXTURE_FORMATS_POINTER`](SDL_PROP_RENDERER_TEXTURE_FORMATS_POINTER.html):
  a (const [SDL_PixelFormat](SDL_PixelFormat.html) \*) array of pixel
  formats, terminated with
  [SDL_PIXELFORMAT_UNKNOWN](SDL_PIXELFORMAT_UNKNOWN.html), representing
  the available texture formats for this renderer.
- [`SDL_PROP_RENDERER_TEXTURE_WRAPPING_BOOLEAN`](SDL_PROP_RENDERER_TEXTURE_WRAPPING_BOOLEAN.html):
  true if the renderer supports
  [SDL_TEXTURE_ADDRESS_WRAP](SDL_TEXTURE_ADDRESS_WRAP.html) on
  non-power-of-two textures.
- [`SDL_PROP_RENDERER_OUTPUT_COLORSPACE_NUMBER`](SDL_PROP_RENDERER_OUTPUT_COLORSPACE_NUMBER.html):
  an [SDL_Colorspace](SDL_Colorspace.html) value describing the
  colorspace for output to the display, defaults to
  [SDL_COLORSPACE_SRGB](SDL_COLORSPACE_SRGB.html).
- [`SDL_PROP_RENDERER_HDR_ENABLED_BOOLEAN`](SDL_PROP_RENDERER_HDR_ENABLED_BOOLEAN.html):
  true if the output colorspace is
  [SDL_COLORSPACE_SRGB_LINEAR](SDL_COLORSPACE_SRGB_LINEAR.html) and the
  renderer is showing on a display with HDR enabled. This property can
  change dynamically when
  [SDL_EVENT_WINDOW_HDR_STATE_CHANGED](SDL_EVENT_WINDOW_HDR_STATE_CHANGED.html)
  is sent.
- [`SDL_PROP_RENDERER_SDR_WHITE_POINT_FLOAT`](SDL_PROP_RENDERER_SDR_WHITE_POINT_FLOAT.html):
  the value of SDR white in the
  [SDL_COLORSPACE_SRGB_LINEAR](SDL_COLORSPACE_SRGB_LINEAR.html)
  colorspace. When HDR is enabled, this value is automatically
  multiplied into the color scale. This property can change dynamically
  when
  [SDL_EVENT_WINDOW_HDR_STATE_CHANGED](SDL_EVENT_WINDOW_HDR_STATE_CHANGED.html)
  is sent.
- [`SDL_PROP_RENDERER_HDR_HEADROOM_FLOAT`](SDL_PROP_RENDERER_HDR_HEADROOM_FLOAT.html):
  the additional high dynamic range that can be displayed, in terms of
  the SDR white point. When HDR is not enabled, this will be 1.0. This
  property can change dynamically when
  [SDL_EVENT_WINDOW_HDR_STATE_CHANGED](SDL_EVENT_WINDOW_HDR_STATE_CHANGED.html)
  is sent.

With the direct3d renderer:

- [`SDL_PROP_RENDERER_D3D9_DEVICE_POINTER`](SDL_PROP_RENDERER_D3D9_DEVICE_POINTER.html):
  the IDirect3DDevice9 associated with the renderer

With the direct3d11 renderer:

- [`SDL_PROP_RENDERER_D3D11_DEVICE_POINTER`](SDL_PROP_RENDERER_D3D11_DEVICE_POINTER.html):
  the ID3D11Device associated with the renderer
- [`SDL_PROP_RENDERER_D3D11_SWAPCHAIN_POINTER`](SDL_PROP_RENDERER_D3D11_SWAPCHAIN_POINTER.html):
  the IDXGISwapChain1 associated with the renderer. This may change when
  the window is resized.

With the direct3d12 renderer:

- [`SDL_PROP_RENDERER_D3D12_DEVICE_POINTER`](SDL_PROP_RENDERER_D3D12_DEVICE_POINTER.html):
  the ID3D12Device associated with the renderer
- [`SDL_PROP_RENDERER_D3D12_SWAPCHAIN_POINTER`](SDL_PROP_RENDERER_D3D12_SWAPCHAIN_POINTER.html):
  the IDXGISwapChain4 associated with the renderer.
- [`SDL_PROP_RENDERER_D3D12_COMMAND_QUEUE_POINTER`](SDL_PROP_RENDERER_D3D12_COMMAND_QUEUE_POINTER.html):
  the ID3D12CommandQueue associated with the renderer

With the vulkan renderer:

- [`SDL_PROP_RENDERER_VULKAN_INSTANCE_POINTER`](SDL_PROP_RENDERER_VULKAN_INSTANCE_POINTER.html):
  the VkInstance associated with the renderer
- [`SDL_PROP_RENDERER_VULKAN_SURFACE_NUMBER`](SDL_PROP_RENDERER_VULKAN_SURFACE_NUMBER.html):
  the VkSurfaceKHR associated with the renderer
- [`SDL_PROP_RENDERER_VULKAN_PHYSICAL_DEVICE_POINTER`](SDL_PROP_RENDERER_VULKAN_PHYSICAL_DEVICE_POINTER.html):
  the VkPhysicalDevice associated with the renderer
- [`SDL_PROP_RENDERER_VULKAN_DEVICE_POINTER`](SDL_PROP_RENDERER_VULKAN_DEVICE_POINTER.html):
  the VkDevice associated with the renderer
- [`SDL_PROP_RENDERER_VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER`](SDL_PROP_RENDERER_VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER.html):
  the queue family index used for rendering
- [`SDL_PROP_RENDERER_VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER`](SDL_PROP_RENDERER_VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER.html):
  the queue family index used for presentation
- [`SDL_PROP_RENDERER_VULKAN_SWAPCHAIN_IMAGE_COUNT_NUMBER`](SDL_PROP_RENDERER_VULKAN_SWAPCHAIN_IMAGE_COUNT_NUMBER.html):
  the number of swapchain images, or potential frames in flight, used by
  the Vulkan renderer

With the gpu renderer:

- [`SDL_PROP_RENDERER_GPU_DEVICE_POINTER`](SDL_PROP_RENDERER_GPU_DEVICE_POINTER.html):
  the [SDL_GPUDevice](SDL_GPUDevice.html) associated with the renderer

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
SDL_Renderer *renderer;
SDL_PropertiesID props = SDL_GetRendererProperties(renderer);
int max_texture_size = (int)SDL_GetNumberProperty(props, SDL_PROP_RENDERER_MAX_TEXTURE_SIZE_NUMBER, 0);
```

</div>

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
