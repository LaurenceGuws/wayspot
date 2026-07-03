###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_Save

Save an SDL_Surface into an image file.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool IMG_Save(SDL_Surface *surface, const char *file);
```

</div>

## Function Parameters

|                |             |                                              |
|----------------|-------------|----------------------------------------------|
| SDL_Surface \* | **surface** | the SDL surface to save.                     |
| const char \*  | **file**    | path on the filesystem to write new file to. |

## Return Value

(bool) Returns true on success or false on failure; call SDL_GetError()
for more information.

## Remarks

If the file already exists, it will be overwritten.

For formats that accept a quality, a default quality of 90 will be used.

## Version

This function is available since SDL_image 3.4.0.

## See Also

- [IMG_SaveTyped_IO](IMG_SaveTyped_IO.html)
- [IMG_SaveAVIF](IMG_SaveAVIF.html)
- [IMG_SaveBMP](IMG_SaveBMP.html)
- [IMG_SaveCUR](IMG_SaveCUR.html)
- [IMG_SaveGIF](IMG_SaveGIF.html)
- [IMG_SaveICO](IMG_SaveICO.html)
- [IMG_SaveJPG](IMG_SaveJPG.html)
- [IMG_SavePNG](IMG_SavePNG.html)
- [IMG_SaveTGA](IMG_SaveTGA.html)
- [IMG_SaveWEBP](IMG_SaveWEBP.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
