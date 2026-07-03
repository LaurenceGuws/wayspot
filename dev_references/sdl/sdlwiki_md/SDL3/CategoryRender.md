# CategoryRender

Header file for SDL 2D rendering functions.

This API supports the following features:

- single pixel points
- single pixel lines
- filled rectangles
- texture images
- 2D polygons

The primitives may be drawn in opaque, blended, or additive modes.

The texture images may be drawn in opaque, blended, or additive modes.
They can have an additional color tint or alpha modulation applied to
them, and may also be stretched with linear interpolation.

This API is designed to accelerate simple 2D operations. You may want
more functionality such as 3D polygons and particle effects, and in that
case you should use SDL's OpenGL/Direct3D support, the SDL3 GPU API, or
one of the many good 3D engines.

These functions must be called from the main thread. See this bug for
details: <https://github.com/libsdl-org/SDL/issues/986>

## Functions

- [SDL_AddVulkanRenderSemaphores](SDL_AddVulkanRenderSemaphores.html)
- [SDL_ConvertEventToRenderCoordinates](SDL_ConvertEventToRenderCoordinates.html)
- [SDL_CreateGPURenderer](SDL_CreateGPURenderer.html)
- [SDL_CreateGPURenderState](SDL_CreateGPURenderState.html)
- [SDL_CreateRenderer](SDL_CreateRenderer.html)
- [SDL_CreateRendererWithProperties](SDL_CreateRendererWithProperties.html)
- [SDL_CreateSoftwareRenderer](SDL_CreateSoftwareRenderer.html)
- [SDL_CreateTexture](SDL_CreateTexture.html)
- [SDL_CreateTextureFromSurface](SDL_CreateTextureFromSurface.html)
- [SDL_CreateTextureWithProperties](SDL_CreateTextureWithProperties.html)
- [SDL_CreateWindowAndRenderer](SDL_CreateWindowAndRenderer.html)
- [SDL_DestroyGPURenderState](SDL_DestroyGPURenderState.html)
- [SDL_DestroyRenderer](SDL_DestroyRenderer.html)
- [SDL_DestroyTexture](SDL_DestroyTexture.html)
- [SDL_FlushRenderer](SDL_FlushRenderer.html)
- [SDL_GetCurrentRenderOutputSize](SDL_GetCurrentRenderOutputSize.html)
- [SDL_GetDefaultTextureScaleMode](SDL_GetDefaultTextureScaleMode.html)
- [SDL_GetGPURendererDevice](SDL_GetGPURendererDevice.html)
- [SDL_GetNumRenderDrivers](SDL_GetNumRenderDrivers.html)
- [SDL_GetRenderClipRect](SDL_GetRenderClipRect.html)
- [SDL_GetRenderColorScale](SDL_GetRenderColorScale.html)
- [SDL_GetRenderDrawBlendMode](SDL_GetRenderDrawBlendMode.html)
- [SDL_GetRenderDrawColor](SDL_GetRenderDrawColor.html)
- [SDL_GetRenderDrawColorFloat](SDL_GetRenderDrawColorFloat.html)
- [SDL_GetRenderDriver](SDL_GetRenderDriver.html)
- [SDL_GetRenderer](SDL_GetRenderer.html)
- [SDL_GetRendererFromTexture](SDL_GetRendererFromTexture.html)
- [SDL_GetRendererName](SDL_GetRendererName.html)
- [SDL_GetRendererProperties](SDL_GetRendererProperties.html)
- [SDL_GetRenderLogicalPresentation](SDL_GetRenderLogicalPresentation.html)
- [SDL_GetRenderLogicalPresentationRect](SDL_GetRenderLogicalPresentationRect.html)
- [SDL_GetRenderMetalCommandEncoder](SDL_GetRenderMetalCommandEncoder.html)
- [SDL_GetRenderMetalLayer](SDL_GetRenderMetalLayer.html)
- [SDL_GetRenderOutputSize](SDL_GetRenderOutputSize.html)
- [SDL_GetRenderSafeArea](SDL_GetRenderSafeArea.html)
- [SDL_GetRenderScale](SDL_GetRenderScale.html)
- [SDL_GetRenderTarget](SDL_GetRenderTarget.html)
- [SDL_GetRenderTextureAddressMode](SDL_GetRenderTextureAddressMode.html)
- [SDL_GetRenderViewport](SDL_GetRenderViewport.html)
- [SDL_GetRenderVSync](SDL_GetRenderVSync.html)
- [SDL_GetRenderWindow](SDL_GetRenderWindow.html)
- [SDL_GetTextureAlphaMod](SDL_GetTextureAlphaMod.html)
- [SDL_GetTextureAlphaModFloat](SDL_GetTextureAlphaModFloat.html)
- [SDL_GetTextureBlendMode](SDL_GetTextureBlendMode.html)
- [SDL_GetTextureColorMod](SDL_GetTextureColorMod.html)
- [SDL_GetTextureColorModFloat](SDL_GetTextureColorModFloat.html)
- [SDL_GetTexturePalette](SDL_GetTexturePalette.html)
- [SDL_GetTextureProperties](SDL_GetTextureProperties.html)
- [SDL_GetTextureScaleMode](SDL_GetTextureScaleMode.html)
- [SDL_GetTextureSize](SDL_GetTextureSize.html)
- [SDL_LockTexture](SDL_LockTexture.html)
- [SDL_LockTextureToSurface](SDL_LockTextureToSurface.html)
- [SDL_RenderClear](SDL_RenderClear.html)
- [SDL_RenderClipEnabled](SDL_RenderClipEnabled.html)
- [SDL_RenderCoordinatesFromWindow](SDL_RenderCoordinatesFromWindow.html)
- [SDL_RenderCoordinatesToWindow](SDL_RenderCoordinatesToWindow.html)
- [SDL_RenderDebugText](SDL_RenderDebugText.html)
- [SDL_RenderDebugTextFormat](SDL_RenderDebugTextFormat.html)
- [SDL_RenderFillRect](SDL_RenderFillRect.html)
- [SDL_RenderFillRects](SDL_RenderFillRects.html)
- [SDL_RenderGeometry](SDL_RenderGeometry.html)
- [SDL_RenderGeometryRaw](SDL_RenderGeometryRaw.html)
- [SDL_RenderLine](SDL_RenderLine.html)
- [SDL_RenderLines](SDL_RenderLines.html)
- [SDL_RenderPoint](SDL_RenderPoint.html)
- [SDL_RenderPoints](SDL_RenderPoints.html)
- [SDL_RenderPresent](SDL_RenderPresent.html)
- [SDL_RenderReadPixels](SDL_RenderReadPixels.html)
- [SDL_RenderRect](SDL_RenderRect.html)
- [SDL_RenderRects](SDL_RenderRects.html)
- [SDL_RenderTexture](SDL_RenderTexture.html)
- [SDL_RenderTexture9Grid](SDL_RenderTexture9Grid.html)
- [SDL_RenderTexture9GridTiled](SDL_RenderTexture9GridTiled.html)
- [SDL_RenderTextureAffine](SDL_RenderTextureAffine.html)
- [SDL_RenderTextureRotated](SDL_RenderTextureRotated.html)
- [SDL_RenderTextureTiled](SDL_RenderTextureTiled.html)
- [SDL_RenderViewportSet](SDL_RenderViewportSet.html)
- [SDL_SetDefaultTextureScaleMode](SDL_SetDefaultTextureScaleMode.html)
- [SDL_SetGPURenderState](SDL_SetGPURenderState.html)
- [SDL_SetGPURenderStateFragmentUniforms](SDL_SetGPURenderStateFragmentUniforms.html)
- [SDL_SetRenderClipRect](SDL_SetRenderClipRect.html)
- [SDL_SetRenderColorScale](SDL_SetRenderColorScale.html)
- [SDL_SetRenderDrawBlendMode](SDL_SetRenderDrawBlendMode.html)
- [SDL_SetRenderDrawColor](SDL_SetRenderDrawColor.html)
- [SDL_SetRenderDrawColorFloat](SDL_SetRenderDrawColorFloat.html)
- [SDL_SetRenderLogicalPresentation](SDL_SetRenderLogicalPresentation.html)
- [SDL_SetRenderScale](SDL_SetRenderScale.html)
- [SDL_SetRenderTarget](SDL_SetRenderTarget.html)
- [SDL_SetRenderTextureAddressMode](SDL_SetRenderTextureAddressMode.html)
- [SDL_SetRenderViewport](SDL_SetRenderViewport.html)
- [SDL_SetRenderVSync](SDL_SetRenderVSync.html)
- [SDL_SetTextureAlphaMod](SDL_SetTextureAlphaMod.html)
- [SDL_SetTextureAlphaModFloat](SDL_SetTextureAlphaModFloat.html)
- [SDL_SetTextureBlendMode](SDL_SetTextureBlendMode.html)
- [SDL_SetTextureColorMod](SDL_SetTextureColorMod.html)
- [SDL_SetTextureColorModFloat](SDL_SetTextureColorModFloat.html)
- [SDL_SetTexturePalette](SDL_SetTexturePalette.html)
- [SDL_SetTextureScaleMode](SDL_SetTextureScaleMode.html)
- [SDL_UnlockTexture](SDL_UnlockTexture.html)
- [SDL_UpdateNVTexture](SDL_UpdateNVTexture.html)
- [SDL_UpdateTexture](SDL_UpdateTexture.html)
- [SDL_UpdateYUVTexture](SDL_UpdateYUVTexture.html)

## Datatypes

- [SDL_GPURenderState](SDL_GPURenderState.html)
- [SDL_Renderer](SDL_Renderer.html)

## Structs

- [SDL_GPURenderStateCreateInfo](SDL_GPURenderStateCreateInfo.html)
- [SDL_Texture](SDL_Texture.html)
- [SDL_Vertex](SDL_Vertex.html)

## Enums

- [SDL_RendererLogicalPresentation](SDL_RendererLogicalPresentation.html)
- [SDL_TextureAccess](SDL_TextureAccess.html)
- [SDL_TextureAddressMode](SDL_TextureAddressMode.html)

## Macros

- [SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE](SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE.html)
- [SDL_GPU_RENDERER](SDL_GPU_RENDERER.html)
- [SDL_SOFTWARE_RENDERER](SDL_SOFTWARE_RENDERER.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
