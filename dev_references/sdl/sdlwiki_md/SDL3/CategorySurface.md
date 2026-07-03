# CategorySurface

SDL surfaces are buffers of pixels in system RAM. These are useful for
passing around and manipulating images that are not stored in GPU
memory.

[SDL_Surface](SDL_Surface.html) makes serious efforts to manage images
in various formats, and provides a reasonable toolbox for transforming
the data, including copying between surfaces, filling rectangles in the
image data, etc.

There is also a simple .bmp loader, [SDL_LoadBMP](SDL_LoadBMP.html)(),
and a simple .png loader, [SDL_LoadPNG](SDL_LoadPNG.html)(). SDL itself
does not provide loaders for other file formats, but there are several
excellent external libraries that do, including its own satellite
library, [SDL_image](../SDL3_image/FrontPage.html) .

In general these functions are thread-safe in that they can be called on
different threads with different surfaces. You should not try to modify
any surface from two threads simultaneously.

## Functions

- [SDL_AddSurfaceAlternateImage](SDL_AddSurfaceAlternateImage.html)
- [SDL_BlitSurface](SDL_BlitSurface.html)
- [SDL_BlitSurface9Grid](SDL_BlitSurface9Grid.html)
- [SDL_BlitSurfaceScaled](SDL_BlitSurfaceScaled.html)
- [SDL_BlitSurfaceTiled](SDL_BlitSurfaceTiled.html)
- [SDL_BlitSurfaceTiledWithScale](SDL_BlitSurfaceTiledWithScale.html)
- [SDL_BlitSurfaceUnchecked](SDL_BlitSurfaceUnchecked.html)
- [SDL_BlitSurfaceUncheckedScaled](SDL_BlitSurfaceUncheckedScaled.html)
- [SDL_ClearSurface](SDL_ClearSurface.html)
- [SDL_ConvertPixels](SDL_ConvertPixels.html)
- [SDL_ConvertPixelsAndColorspace](SDL_ConvertPixelsAndColorspace.html)
- [SDL_ConvertSurface](SDL_ConvertSurface.html)
- [SDL_ConvertSurfaceAndColorspace](SDL_ConvertSurfaceAndColorspace.html)
- [SDL_CreateSurface](SDL_CreateSurface.html)
- [SDL_CreateSurfaceFrom](SDL_CreateSurfaceFrom.html)
- [SDL_CreateSurfacePalette](SDL_CreateSurfacePalette.html)
- [SDL_DestroySurface](SDL_DestroySurface.html)
- [SDL_DuplicateSurface](SDL_DuplicateSurface.html)
- [SDL_FillSurfaceRect](SDL_FillSurfaceRect.html)
- [SDL_FillSurfaceRects](SDL_FillSurfaceRects.html)
- [SDL_FlipSurface](SDL_FlipSurface.html)
- [SDL_GetSurfaceAlphaMod](SDL_GetSurfaceAlphaMod.html)
- [SDL_GetSurfaceBlendMode](SDL_GetSurfaceBlendMode.html)
- [SDL_GetSurfaceClipRect](SDL_GetSurfaceClipRect.html)
- [SDL_GetSurfaceColorKey](SDL_GetSurfaceColorKey.html)
- [SDL_GetSurfaceColorMod](SDL_GetSurfaceColorMod.html)
- [SDL_GetSurfaceColorspace](SDL_GetSurfaceColorspace.html)
- [SDL_GetSurfaceImages](SDL_GetSurfaceImages.html)
- [SDL_GetSurfacePalette](SDL_GetSurfacePalette.html)
- [SDL_GetSurfaceProperties](SDL_GetSurfaceProperties.html)
- [SDL_LoadBMP](SDL_LoadBMP.html)
- [SDL_LoadBMP_IO](SDL_LoadBMP_IO.html)
- [SDL_LoadPNG](SDL_LoadPNG.html)
- [SDL_LoadPNG_IO](SDL_LoadPNG_IO.html)
- [SDL_LoadSurface](SDL_LoadSurface.html)
- [SDL_LoadSurface_IO](SDL_LoadSurface_IO.html)
- [SDL_LockSurface](SDL_LockSurface.html)
- [SDL_MapSurfaceRGB](SDL_MapSurfaceRGB.html)
- [SDL_MapSurfaceRGBA](SDL_MapSurfaceRGBA.html)
- [SDL_PremultiplyAlpha](SDL_PremultiplyAlpha.html)
- [SDL_PremultiplySurfaceAlpha](SDL_PremultiplySurfaceAlpha.html)
- [SDL_ReadSurfacePixel](SDL_ReadSurfacePixel.html)
- [SDL_ReadSurfacePixelFloat](SDL_ReadSurfacePixelFloat.html)
- [SDL_RemoveSurfaceAlternateImages](SDL_RemoveSurfaceAlternateImages.html)
- [SDL_RotateSurface](SDL_RotateSurface.html)
- [SDL_SaveBMP](SDL_SaveBMP.html)
- [SDL_SaveBMP_IO](SDL_SaveBMP_IO.html)
- [SDL_SavePNG](SDL_SavePNG.html)
- [SDL_SavePNG_IO](SDL_SavePNG_IO.html)
- [SDL_ScaleSurface](SDL_ScaleSurface.html)
- [SDL_SetSurfaceAlphaMod](SDL_SetSurfaceAlphaMod.html)
- [SDL_SetSurfaceBlendMode](SDL_SetSurfaceBlendMode.html)
- [SDL_SetSurfaceClipRect](SDL_SetSurfaceClipRect.html)
- [SDL_SetSurfaceColorKey](SDL_SetSurfaceColorKey.html)
- [SDL_SetSurfaceColorMod](SDL_SetSurfaceColorMod.html)
- [SDL_SetSurfaceColorspace](SDL_SetSurfaceColorspace.html)
- [SDL_SetSurfacePalette](SDL_SetSurfacePalette.html)
- [SDL_SetSurfaceRLE](SDL_SetSurfaceRLE.html)
- [SDL_StretchSurface](SDL_StretchSurface.html)
- [SDL_SurfaceHasAlternateImages](SDL_SurfaceHasAlternateImages.html)
- [SDL_SurfaceHasColorKey](SDL_SurfaceHasColorKey.html)
- [SDL_SurfaceHasRLE](SDL_SurfaceHasRLE.html)
- [SDL_UnlockSurface](SDL_UnlockSurface.html)
- [SDL_WriteSurfacePixel](SDL_WriteSurfacePixel.html)
- [SDL_WriteSurfacePixelFloat](SDL_WriteSurfacePixelFloat.html)

## Datatypes

- [SDL_SurfaceFlags](SDL_SurfaceFlags.html)

## Structs

- [SDL_Surface](SDL_Surface.html)

## Enums

- [SDL_FlipMode](SDL_FlipMode.html)
- [SDL_ScaleMode](SDL_ScaleMode.html)

## Macros

- [SDL_MUSTLOCK](SDL_MUSTLOCK.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
