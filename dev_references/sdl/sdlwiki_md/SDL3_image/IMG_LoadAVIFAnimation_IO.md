###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_LoadAVIFAnimation_IO

Load an AVIF animation directly from an SDL_IOStream.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
IMG_Animation* IMG_LoadAVIFAnimation_IO(SDL_IOStream *src);
```

</div>

## Function Parameters

|                 |         |                                              |
|-----------------|---------|----------------------------------------------|
| SDL_IOStream \* | **src** | an SDL_IOStream that data will be read from. |

## Return Value

([IMG_Animation](IMG_Animation.html) \*) Returns a new
[IMG_Animation](IMG_Animation.html), or NULL on error.

## Remarks

If you know you definitely have an AVIF animation, you can call this
function, which will skip SDL_image's file format detection routines.
Generally it's better to use the abstract interfaces; also, there is
only an SDL_IOStream interface available here.

When done with the returned animation, the app should dispose of it with
a call to [IMG_FreeAnimation](IMG_FreeAnimation.html)().

## Version

This function is available since SDL_image 3.4.0.

## See Also

- [IMG_isAVIF](IMG_isAVIF.html)
- [IMG_LoadAnimation](IMG_LoadAnimation.html)
- [IMG_LoadAnimation_IO](IMG_LoadAnimation_IO.html)
- [IMG_LoadAnimationTyped_IO](IMG_LoadAnimationTyped_IO.html)
- [IMG_LoadANIAnimation_IO](IMG_LoadANIAnimation_IO.html)
- [IMG_LoadAPNGAnimation_IO](IMG_LoadAPNGAnimation_IO.html)
- [IMG_LoadGIFAnimation_IO](IMG_LoadGIFAnimation_IO.html)
- [IMG_LoadWEBPAnimation_IO](IMG_LoadWEBPAnimation_IO.html)
- [IMG_FreeAnimation](IMG_FreeAnimation.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
