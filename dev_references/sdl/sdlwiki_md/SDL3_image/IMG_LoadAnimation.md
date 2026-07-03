###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_LoadAnimation

Load an animation from a file.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
IMG_Animation * IMG_LoadAnimation(const char *file);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **file** | path on the filesystem containing an animated image. |

## Return Value

([IMG_Animation](IMG_Animation.html) \*) Returns a new
[IMG_Animation](IMG_Animation.html), or NULL on error.

## Remarks

When done with the returned animation, the app should dispose of it with
a call to [IMG_FreeAnimation](IMG_FreeAnimation.html)().

## Version

This function is available since SDL_image 3.0.0.

## See Also

- [IMG_CreateAnimatedCursor](IMG_CreateAnimatedCursor.html)
- [IMG_LoadAnimation_IO](IMG_LoadAnimation_IO.html)
- [IMG_LoadAnimationTyped_IO](IMG_LoadAnimationTyped_IO.html)
- [IMG_LoadANIAnimation_IO](IMG_LoadANIAnimation_IO.html)
- [IMG_LoadAPNGAnimation_IO](IMG_LoadAPNGAnimation_IO.html)
- [IMG_LoadAVIFAnimation_IO](IMG_LoadAVIFAnimation_IO.html)
- [IMG_LoadGIFAnimation_IO](IMG_LoadGIFAnimation_IO.html)
- [IMG_LoadWEBPAnimation_IO](IMG_LoadWEBPAnimation_IO.html)
- [IMG_FreeAnimation](IMG_FreeAnimation.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
