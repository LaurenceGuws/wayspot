# SDL_CreateTextureWithProperties

Create a texture for a rendering context with the specified properties.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Texture * SDL_CreateTextureWithProperties(SDL_Renderer *renderer, SDL_PropertiesID props);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to use. |

## Return Value

([SDL_Texture](SDL_Texture.html) \*) Returns the created texture or NULL
on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

These are the supported properties:

- [`SDL_PROP_TEXTURE_CREATE_COLORSPACE_NUMBER`](SDL_PROP_TEXTURE_CREATE_COLORSPACE_NUMBER.html):
  an [SDL_Colorspace](SDL_Colorspace.html) value describing the texture
  colorspace, defaults to
  [SDL_COLORSPACE_SRGB_LINEAR](SDL_COLORSPACE_SRGB_LINEAR.html) for
  floating point textures,
  [SDL_COLORSPACE_HDR10](SDL_COLORSPACE_HDR10.html) for 10-bit textures,
  [SDL_COLORSPACE_SRGB](SDL_COLORSPACE_SRGB.html) for other RGB textures
  and [SDL_COLORSPACE_JPEG](SDL_COLORSPACE_JPEG.html) for YUV textures.
- [`SDL_PROP_TEXTURE_CREATE_FORMAT_NUMBER`](SDL_PROP_TEXTURE_CREATE_FORMAT_NUMBER.html):
  one of the enumerated values in
  [SDL_PixelFormat](SDL_PixelFormat.html), defaults to the best RGBA
  format for the renderer
- [`SDL_PROP_TEXTURE_CREATE_ACCESS_NUMBER`](SDL_PROP_TEXTURE_CREATE_ACCESS_NUMBER.html):
  one of the enumerated values in
  [SDL_TextureAccess](SDL_TextureAccess.html), defaults to
  [SDL_TEXTUREACCESS_STATIC](SDL_TEXTUREACCESS_STATIC.html)
- [`SDL_PROP_TEXTURE_CREATE_WIDTH_NUMBER`](SDL_PROP_TEXTURE_CREATE_WIDTH_NUMBER.html):
  the width of the texture in pixels, required
- [`SDL_PROP_TEXTURE_CREATE_HEIGHT_NUMBER`](SDL_PROP_TEXTURE_CREATE_HEIGHT_NUMBER.html):
  the height of the texture in pixels, required
- [`SDL_PROP_TEXTURE_CREATE_PALETTE_POINTER`](SDL_PROP_TEXTURE_CREATE_PALETTE_POINTER.html):
  an [SDL_Palette](SDL_Palette.html) to use with palettized texture
  formats. This can be set later with
  [SDL_SetTexturePalette](SDL_SetTexturePalette.html)()
- [`SDL_PROP_TEXTURE_CREATE_SDR_WHITE_POINT_FLOAT`](SDL_PROP_TEXTURE_CREATE_SDR_WHITE_POINT_FLOAT.html):
  for HDR10 and floating point textures, this defines the value of 100%
  diffuse white, with higher values being displayed in the High Dynamic
  Range headroom. This defaults to 100 for HDR10 textures and 1.0 for
  floating point textures.
- [`SDL_PROP_TEXTURE_CREATE_HDR_HEADROOM_FLOAT`](SDL_PROP_TEXTURE_CREATE_HDR_HEADROOM_FLOAT.html):
  for HDR10 and floating point textures, this defines the maximum
  dynamic range used by the content, in terms of the SDR white point.
  This would be equivalent to maxCLL /
  [SDL_PROP_TEXTURE_CREATE_SDR_WHITE_POINT_FLOAT](SDL_PROP_TEXTURE_CREATE_SDR_WHITE_POINT_FLOAT.html)
  for HDR10 content. If this is defined, any values outside the range
  supported by the display will be scaled into the available HDR
  headroom, otherwise they are clipped.

With the direct3d11 renderer:

- [`SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_POINTER`](SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_POINTER.html):
  the ID3D11Texture2D associated with the texture, if you want to wrap
  an existing texture.
- [`SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_U_POINTER`](SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_U_POINTER.html):
  the ID3D11Texture2D associated with the U plane of a YUV texture, if
  you want to wrap an existing texture.
- [`SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_V_POINTER`](SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_V_POINTER.html):
  the ID3D11Texture2D associated with the V plane of a YUV texture, if
  you want to wrap an existing texture.

With the direct3d12 renderer:

- [`SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_POINTER`](SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_POINTER.html):
  the ID3D12Resource associated with the texture, if you want to wrap an
  existing texture.
- [`SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_U_POINTER`](SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_U_POINTER.html):
  the ID3D12Resource associated with the U plane of a YUV texture, if
  you want to wrap an existing texture.
- [`SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_V_POINTER`](SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_V_POINTER.html):
  the ID3D12Resource associated with the V plane of a YUV texture, if
  you want to wrap an existing texture.

With the metal renderer:

- [`SDL_PROP_TEXTURE_CREATE_METAL_PIXELBUFFER_POINTER`](SDL_PROP_TEXTURE_CREATE_METAL_PIXELBUFFER_POINTER.html):
  the CVPixelBufferRef associated with the texture, if you want to
  create a texture from an existing pixel buffer.

With the opengl renderer:

- [`SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_NUMBER`](SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_NUMBER.html):
  the GLuint texture associated with the texture, if you want to wrap an
  existing texture.
- [`SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_UV_NUMBER`](SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_UV_NUMBER.html):
  the GLuint texture associated with the UV plane of an NV12 texture, if
  you want to wrap an existing texture.
- [`SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_U_NUMBER`](SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_U_NUMBER.html):
  the GLuint texture associated with the U plane of a YUV texture, if
  you want to wrap an existing texture.
- [`SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_V_NUMBER`](SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_V_NUMBER.html):
  the GLuint texture associated with the V plane of a YUV texture, if
  you want to wrap an existing texture.

With the opengles2 renderer:

- [`SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_NUMBER`](SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_NUMBER.html):
  the GLuint texture associated with the texture, if you want to wrap an
  existing texture.
- [`SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_NUMBER`](SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_NUMBER.html):
  the GLuint texture associated with the texture, if you want to wrap an
  existing texture.
- [`SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_UV_NUMBER`](SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_UV_NUMBER.html):
  the GLuint texture associated with the UV plane of an NV12 texture, if
  you want to wrap an existing texture.
- [`SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_U_NUMBER`](SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_U_NUMBER.html):
  the GLuint texture associated with the U plane of a YUV texture, if
  you want to wrap an existing texture.
- [`SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_V_NUMBER`](SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_V_NUMBER.html):
  the GLuint texture associated with the V plane of a YUV texture, if
  you want to wrap an existing texture.

With the vulkan renderer:

- [`SDL_PROP_TEXTURE_CREATE_VULKAN_TEXTURE_NUMBER`](SDL_PROP_TEXTURE_CREATE_VULKAN_TEXTURE_NUMBER.html):
  the VkImage associated with the texture, if you want to wrap an
  existing texture.
- [`SDL_PROP_TEXTURE_CREATE_VULKAN_LAYOUT_NUMBER`](SDL_PROP_TEXTURE_CREATE_VULKAN_LAYOUT_NUMBER.html):
  the VkImageLayout for the VkImage, defaults to
  VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL.

With the GPU renderer:

- [`SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_POINTER`](SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_POINTER.html):
  the [SDL_GPUTexture](SDL_GPUTexture.html) associated with the texture,
  if you want to wrap an existing texture.
- [`SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_UV_NUMBER`](SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_UV_NUMBER.html):
  the [SDL_GPUTexture](SDL_GPUTexture.html) associated with the UV plane
  of an NV12 texture, if you want to wrap an existing texture.
- [`SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_U_NUMBER`](SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_U_NUMBER.html):
  the [SDL_GPUTexture](SDL_GPUTexture.html) associated with the U plane
  of a YUV texture, if you want to wrap an existing texture.
- [`SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_V_NUMBER`](SDL_PROP_TEXTURE_CREATE_GPU_TEXTURE_V_NUMBER.html):
  the [SDL_GPUTexture](SDL_GPUTexture.html) associated with the V plane
  of a YUV texture, if you want to wrap an existing texture.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateProperties](SDL_CreateProperties.html)
- [SDL_CreateTexture](SDL_CreateTexture.html)
- [SDL_CreateTextureFromSurface](SDL_CreateTextureFromSurface.html)
- [SDL_DestroyTexture](SDL_DestroyTexture.html)
- [SDL_GetTextureSize](SDL_GetTextureSize.html)
- [SDL_UpdateTexture](SDL_UpdateTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
