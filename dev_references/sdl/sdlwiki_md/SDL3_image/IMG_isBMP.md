###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_isBMP

Detect BMP image data on a readable/seekable SDL_IOStream.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool IMG_isBMP(SDL_IOStream *src);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| SDL_IOStream \* | **src** | a seekable/readable SDL_IOStream to provide image data. |

## Return Value

(bool) Returns true if this is BMP data, false otherwise.

## Remarks

This function attempts to determine if a file is a given filetype,
reading the least amount possible from the SDL_IOStream (usually a few
bytes).

There is no distinction made between "not the filetype in question" and
basic i/o errors.

This function will always attempt to seek `src` back to where it started
when this function was called, but it will not report any errors in
doing so, but assuming seeking works, this means you can immediately use
this with a different [IMG_isTYPE](IMG_isTYPE.html) function, or load
the image without further seeking.

You do not need to call this function to load data; SDL_image can work
to determine file type in many cases in its standard load functions.

## Version

This function is available since SDL_image 3.0.0.

## See Also

- [IMG_isANI](IMG_isANI.html)
- [IMG_isAVIF](IMG_isAVIF.html)
- [IMG_isCUR](IMG_isCUR.html)
- [IMG_isGIF](IMG_isGIF.html)
- [IMG_isICO](IMG_isICO.html)
- [IMG_isJPG](IMG_isJPG.html)
- [IMG_isJXL](IMG_isJXL.html)
- [IMG_isLBM](IMG_isLBM.html)
- [IMG_isPCX](IMG_isPCX.html)
- [IMG_isPNG](IMG_isPNG.html)
- [IMG_isPNM](IMG_isPNM.html)
- [IMG_isQOI](IMG_isQOI.html)
- [IMG_isSVG](IMG_isSVG.html)
- [IMG_isTIF](IMG_isTIF.html)
- [IMG_isWEBP](IMG_isWEBP.html)
- [IMG_isXCF](IMG_isXCF.html)
- [IMG_isXPM](IMG_isXPM.html)
- [IMG_isXV](IMG_isXV.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
