###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_GetClipboardImage

Get the image currently in the clipboard.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Surface * IMG_GetClipboardImage(void);
```

</div>

## Return Value

(SDL_Surface \*) Returns a new SDL surface, or NULL if no supported
image is available.

## Remarks

When done with the returned surface, the app should dispose of it with a
call to SDL_DestroySurface().

## Version

This function is available since SDL_image 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
