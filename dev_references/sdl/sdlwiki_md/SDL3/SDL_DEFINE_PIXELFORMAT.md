# SDL_DEFINE_PIXELFORMAT

A macro for defining custom non-FourCC pixel formats.

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_DEFINE_PIXELFORMAT(type, order, layout, bits, bytes) \
    ((1 << 28) | ((type) << 24) | ((order) << 20) | ((layout) << 16) | \
     ((bits) << 8) | ((bytes) << 0))
```

</div>

## Macro Parameters

|  |  |
|----|----|
| **type** | the type of the new format, probably a [SDL_PixelType](SDL_PixelType.html) value. |
| **order** | the order of the new format, probably a [SDL_BitmapOrder](SDL_BitmapOrder.html), [SDL_PackedOrder](SDL_PackedOrder.html), or [SDL_ArrayOrder](SDL_ArrayOrder.html) value. |
| **layout** | the layout of the new format, probably an [SDL_PackedLayout](SDL_PackedLayout.html) value or zero. |
| **bits** | the number of bits per pixel of the new format. |
| **bytes** | the number of bytes per pixel of the new format. |

## Return Value

Returns a format value in the style of
[SDL_PixelFormat](SDL_PixelFormat.html).

## Remarks

For example, defining
[SDL_PIXELFORMAT_RGBA8888](SDL_PIXELFORMAT_RGBA8888.html) looks like
this:

<div id="cb2" class="sourceCode">

``` sourceCode
SDL_DEFINE_PIXELFORMAT(SDL_PIXELTYPE_PACKED32, SDL_PACKEDORDER_RGBA, SDL_PACKEDLAYOUT_8888, 32, 4)
```

</div>

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPixels](CategoryPixels.html)
