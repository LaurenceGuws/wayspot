# CategoryPixels

SDL offers facilities for pixel management.

Largely these facilities deal with pixel *format*: what does this set of
bits represent?

If you mostly want to think of a pixel as some combination of red,
green, blue, and maybe alpha intensities, this is all pretty
straightforward, and in many cases, is enough information to build a
perfectly fine game.

However, the actual definition of a pixel is more complex than that:

Pixels are a representation of a color in a particular color space.

The first characteristic of a color space is the color type. SDL
understands two different color types, RGB and YCbCr, or in SDL also
referred to as YUV.

RGB colors consist of red, green, and blue channels of color that are
added together to represent the colors we see on the screen.

<https://en.wikipedia.org/wiki/RGB_color_model>

YCbCr colors represent colors as a Y luma brightness component and red
and blue chroma color offsets. This color representation takes advantage
of the fact that the human eye is more sensitive to brightness than the
color in an image. The Cb and Cr components are often compressed and
have lower resolution than the luma component.

<https://en.wikipedia.org/wiki/YCbCr>

When the color information in YCbCr is compressed, the Y pixels are left
at full resolution and each Cr and Cb pixel represents an average of the
color information in a block of Y pixels. The chroma location determines
where in that block of pixels the color information is coming from.

The color range defines how much of the pixel to use when converting a
pixel into a color on the display. When the full color range is used,
the entire numeric range of the pixel bits is significant. When narrow
color range is used, for historical reasons, the pixel uses only a
portion of the numeric range to represent colors.

The color primaries and white point are a definition of the colors in
the color space relative to the standard XYZ color space.

<https://en.wikipedia.org/wiki/CIE_1931_color_space>

The transfer characteristic, or opto-electrical transfer function
(OETF), is the way a color is converted from mathematically linear space
into a non-linear output signals.

<https://en.wikipedia.org/wiki/Rec._709#Transfer_characteristics>

The matrix coefficients are used to convert between YCbCr and RGB
colors.

## Functions

- [SDL_CreatePalette](SDL_CreatePalette.html)
- [SDL_DestroyPalette](SDL_DestroyPalette.html)
- [SDL_GetMasksForPixelFormat](SDL_GetMasksForPixelFormat.html)
- [SDL_GetPixelFormatDetails](SDL_GetPixelFormatDetails.html)
- [SDL_GetPixelFormatForMasks](SDL_GetPixelFormatForMasks.html)
- [SDL_GetPixelFormatName](SDL_GetPixelFormatName.html)
- [SDL_GetRGB](SDL_GetRGB.html)
- [SDL_GetRGBA](SDL_GetRGBA.html)
- [SDL_MapRGB](SDL_MapRGB.html)
- [SDL_MapRGBA](SDL_MapRGBA.html)
- [SDL_MapSurfaceRGB](SDL_MapSurfaceRGB.html)
- [SDL_MapSurfaceRGBA](SDL_MapSurfaceRGBA.html)
- [SDL_SetPaletteColors](SDL_SetPaletteColors.html)

## Datatypes

- (none.)

## Structs

- [SDL_Color](SDL_Color.html)
- [SDL_FColor](SDL_FColor.html)
- [SDL_Palette](SDL_Palette.html)
- [SDL_PixelFormatDetails](SDL_PixelFormatDetails.html)

## Enums

- [SDL_ArrayOrder](SDL_ArrayOrder.html)
- [SDL_BitmapOrder](SDL_BitmapOrder.html)
- [SDL_ChromaLocation](SDL_ChromaLocation.html)
- [SDL_ColorPrimaries](SDL_ColorPrimaries.html)
- [SDL_ColorRange](SDL_ColorRange.html)
- [SDL_Colorspace](SDL_Colorspace.html)
- [SDL_ColorType](SDL_ColorType.html)
- [SDL_MatrixCoefficients](SDL_MatrixCoefficients.html)
- [SDL_PackedLayout](SDL_PackedLayout.html)
- [SDL_PackedOrder](SDL_PackedOrder.html)
- [SDL_PixelFormat](SDL_PixelFormat.html)
- [SDL_PixelType](SDL_PixelType.html)
- [SDL_TransferCharacteristics](SDL_TransferCharacteristics.html)

## Macros

- [SDL_ALPHA_OPAQUE](SDL_ALPHA_OPAQUE.html)
- [SDL_ALPHA_OPAQUE_FLOAT](SDL_ALPHA_OPAQUE_FLOAT.html)
- [SDL_ALPHA_TRANSPARENT](SDL_ALPHA_TRANSPARENT.html)
- [SDL_ALPHA_TRANSPARENT_FLOAT](SDL_ALPHA_TRANSPARENT_FLOAT.html)
- [SDL_BITSPERPIXEL](SDL_BITSPERPIXEL.html)
- [SDL_BYTESPERPIXEL](SDL_BYTESPERPIXEL.html)
- [SDL_COLORSPACECHROMA](SDL_COLORSPACECHROMA.html)
- [SDL_COLORSPACEMATRIX](SDL_COLORSPACEMATRIX.html)
- [SDL_COLORSPACEPRIMARIES](SDL_COLORSPACEPRIMARIES.html)
- [SDL_COLORSPACERANGE](SDL_COLORSPACERANGE.html)
- [SDL_COLORSPACETRANSFER](SDL_COLORSPACETRANSFER.html)
- [SDL_COLORSPACETYPE](SDL_COLORSPACETYPE.html)
- [SDL_DEFINE_COLORSPACE](SDL_DEFINE_COLORSPACE.html)
- [SDL_DEFINE_PIXELFORMAT](SDL_DEFINE_PIXELFORMAT.html)
- [SDL_DEFINE_PIXELFOURCC](SDL_DEFINE_PIXELFOURCC.html)
- [SDL_ISCOLORSPACE_FULL_RANGE](SDL_ISCOLORSPACE_FULL_RANGE.html)
- [SDL_ISCOLORSPACE_LIMITED_RANGE](SDL_ISCOLORSPACE_LIMITED_RANGE.html)
- [SDL_ISCOLORSPACE_MATRIX_BT2020_NCL](SDL_ISCOLORSPACE_MATRIX_BT2020_NCL.html)
- [SDL_ISCOLORSPACE_MATRIX_BT601](SDL_ISCOLORSPACE_MATRIX_BT601.html)
- [SDL_ISCOLORSPACE_MATRIX_BT709](SDL_ISCOLORSPACE_MATRIX_BT709.html)
- [SDL_ISPIXELFORMAT_10BIT](SDL_ISPIXELFORMAT_10BIT.html)
- [SDL_ISPIXELFORMAT_ALPHA](SDL_ISPIXELFORMAT_ALPHA.html)
- [SDL_ISPIXELFORMAT_ARRAY](SDL_ISPIXELFORMAT_ARRAY.html)
- [SDL_ISPIXELFORMAT_FLOAT](SDL_ISPIXELFORMAT_FLOAT.html)
- [SDL_ISPIXELFORMAT_FOURCC](SDL_ISPIXELFORMAT_FOURCC.html)
- [SDL_ISPIXELFORMAT_INDEXED](SDL_ISPIXELFORMAT_INDEXED.html)
- [SDL_ISPIXELFORMAT_PACKED](SDL_ISPIXELFORMAT_PACKED.html)
- [SDL_PIXELFLAG](SDL_PIXELFLAG.html)
- [SDL_PIXELLAYOUT](SDL_PIXELLAYOUT.html)
- [SDL_PIXELORDER](SDL_PIXELORDER.html)
- [SDL_PIXELTYPE](SDL_PIXELTYPE.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
