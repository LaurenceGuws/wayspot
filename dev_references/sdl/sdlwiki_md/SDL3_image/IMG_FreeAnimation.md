###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_FreeAnimation

Dispose of an [IMG_Animation](IMG_Animation.html) and free its
resources.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void IMG_FreeAnimation(IMG_Animation *anim);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [IMG_Animation](IMG_Animation.html) \* | **anim** | [IMG_Animation](IMG_Animation.html) to dispose of. |

## Remarks

The provided `anim` pointer is not valid once this call returns.

## Version

This function is available since SDL_image 3.0.0.

## See Also

- [IMG_LoadAnimation](IMG_LoadAnimation.html)
- [IMG_LoadAnimation_IO](IMG_LoadAnimation_IO.html)
- [IMG_LoadAnimationTyped_IO](IMG_LoadAnimationTyped_IO.html)
- [IMG_LoadANIAnimation_IO](IMG_LoadANIAnimation_IO.html)
- [IMG_LoadAPNGAnimation_IO](IMG_LoadAPNGAnimation_IO.html)
- [IMG_LoadAVIFAnimation_IO](IMG_LoadAVIFAnimation_IO.html)
- [IMG_LoadGIFAnimation_IO](IMG_LoadGIFAnimation_IO.html)
- [IMG_LoadWEBPAnimation_IO](IMG_LoadWEBPAnimation_IO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
