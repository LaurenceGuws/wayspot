# SDL_ComposeCustomBlendMode

Compose a custom blend mode for renderers.

## Header File

Defined in
[\<SDL3/SDL_blendmode.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_blendmode.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_BlendMode SDL_ComposeCustomBlendMode(SDL_BlendFactor srcColorFactor,
                                     SDL_BlendFactor dstColorFactor,
                                     SDL_BlendOperation colorOperation,
                                     SDL_BlendFactor srcAlphaFactor,
                                     SDL_BlendFactor dstAlphaFactor,
                                     SDL_BlendOperation alphaOperation);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_BlendFactor](SDL_BlendFactor.html) | **srcColorFactor** | the [SDL_BlendFactor](SDL_BlendFactor.html) applied to the red, green, and blue components of the source pixels. |
| [SDL_BlendFactor](SDL_BlendFactor.html) | **dstColorFactor** | the [SDL_BlendFactor](SDL_BlendFactor.html) applied to the red, green, and blue components of the destination pixels. |
| [SDL_BlendOperation](SDL_BlendOperation.html) | **colorOperation** | the [SDL_BlendOperation](SDL_BlendOperation.html) used to combine the red, green, and blue components of the source and destination pixels. |
| [SDL_BlendFactor](SDL_BlendFactor.html) | **srcAlphaFactor** | the [SDL_BlendFactor](SDL_BlendFactor.html) applied to the alpha component of the source pixels. |
| [SDL_BlendFactor](SDL_BlendFactor.html) | **dstAlphaFactor** | the [SDL_BlendFactor](SDL_BlendFactor.html) applied to the alpha component of the destination pixels. |
| [SDL_BlendOperation](SDL_BlendOperation.html) | **alphaOperation** | the [SDL_BlendOperation](SDL_BlendOperation.html) used to combine the alpha component of the source and destination pixels. |

## Return Value

([SDL_BlendMode](SDL_BlendMode.html)) Returns an
[SDL_BlendMode](SDL_BlendMode.html) that represents the chosen factors
and operations.

## Remarks

The functions
[SDL_SetRenderDrawBlendMode](SDL_SetRenderDrawBlendMode.html) and
[SDL_SetTextureBlendMode](SDL_SetTextureBlendMode.html) accept the
[SDL_BlendMode](SDL_BlendMode.html) returned by this function if the
renderer supports it.

A blend mode controls how the pixels from a drawing operation (source)
get combined with the pixels from the render target (destination).
First, the components of the source and destination pixels get
multiplied with their blend factors. Then, the blend operation takes the
two products and calculates the result that will get stored in the
render target.

Expressed in pseudocode, it would look like this:

<div id="cb2" class="sourceCode">

``` sourceCode
dstRGB = colorOperation(srcRGB * srcColorFactor, dstRGB * dstColorFactor);
dstA = alphaOperation(srcA * srcAlphaFactor, dstA * dstAlphaFactor);
```

</div>

Where the functions `colorOperation(src, dst)` and
`alphaOperation(src, dst)` can return one of the following:

- `src + dst`
- `src - dst`
- `dst - src`
- `min(src, dst)`
- `max(src, dst)`

The red, green, and blue components are always multiplied with the
first, second, and third components of the
[SDL_BlendFactor](SDL_BlendFactor.html), respectively. The fourth
component is not used.

The alpha component is always multiplied with the fourth component of
the [SDL_BlendFactor](SDL_BlendFactor.html). The other components are
not used in the alpha calculation.

Support for these blend modes varies for each renderer. To check if a
specific [SDL_BlendMode](SDL_BlendMode.html) is supported, create a
renderer and pass it to either
[SDL_SetRenderDrawBlendMode](SDL_SetRenderDrawBlendMode.html) or
[SDL_SetTextureBlendMode](SDL_SetTextureBlendMode.html). They will
return with an error if the blend mode is not supported.

This list describes the support of custom blend modes for each renderer.
All renderers support the four blend modes listed in the
[SDL_BlendMode](SDL_BlendMode.html) enumeration.

- **direct3d**: Supports all operations with all factors. However, some
  factors produce unexpected results with
  [`SDL_BLENDOPERATION_MINIMUM`](SDL_BLENDOPERATION_MINIMUM.html) and
  [`SDL_BLENDOPERATION_MAXIMUM`](SDL_BLENDOPERATION_MAXIMUM.html).
- **direct3d11**: Same as Direct3D 9.
- **opengl**: Supports the
  [`SDL_BLENDOPERATION_ADD`](SDL_BLENDOPERATION_ADD.html) operation with
  all factors. OpenGL versions 1.1, 1.2, and 1.3 do not work correctly
  here.
- **opengles2**: Supports the
  [`SDL_BLENDOPERATION_ADD`](SDL_BLENDOPERATION_ADD.html),
  [`SDL_BLENDOPERATION_SUBTRACT`](SDL_BLENDOPERATION_SUBTRACT.html),
  [`SDL_BLENDOPERATION_REV_SUBTRACT`](SDL_BLENDOPERATION_REV_SUBTRACT.html)
  operations with all factors.
- **psp**: No custom blend mode support.
- **software**: No custom blend mode support.

Some renderers do not provide an alpha component for the default render
target. The
[`SDL_BLENDFACTOR_DST_ALPHA`](SDL_BLENDFACTOR_DST_ALPHA.html) and
[`SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA`](SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA.html)
factors do not have an effect in this case.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetRenderDrawBlendMode](SDL_SetRenderDrawBlendMode.html)
- [SDL_GetRenderDrawBlendMode](SDL_GetRenderDrawBlendMode.html)
- [SDL_SetTextureBlendMode](SDL_SetTextureBlendMode.html)
- [SDL_GetTextureBlendMode](SDL_GetTextureBlendMode.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryBlendmode](CategoryBlendmode.html)
