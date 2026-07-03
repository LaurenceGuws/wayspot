###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_LoadTGA_IO

Load a TGA image directly.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Surface * IMG_LoadTGA_IO(SDL_IOStream *src);
```

</div>

## Function Parameters

|                 |         |                                          |
|-----------------|---------|------------------------------------------|
| SDL_IOStream \* | **src** | an SDL_IOStream to load image data from. |

## Return Value

(SDL_Surface \*) Returns SDL surface, or NULL on error.

## Remarks

If you know you definitely have a TGA image, you can call this function,
which will skip SDL_image's file format detection routines. Generally
it's better to use the abstract interfaces; also, there is only an
SDL_IOStream interface available here.

## Version

This function is available since SDL_image 3.0.0.

## See Also

- [IMG_LoadAVIF_IO](IMG_LoadAVIF_IO.html)
- [IMG_LoadBMP_IO](IMG_LoadBMP_IO.html)
- [IMG_LoadCUR_IO](IMG_LoadCUR_IO.html)
- [IMG_LoadGIF_IO](IMG_LoadGIF_IO.html)
- [IMG_LoadICO_IO](IMG_LoadICO_IO.html)
- [IMG_LoadJPG_IO](IMG_LoadJPG_IO.html)
- [IMG_LoadJXL_IO](IMG_LoadJXL_IO.html)
- [IMG_LoadLBM_IO](IMG_LoadLBM_IO.html)
- [IMG_LoadPCX_IO](IMG_LoadPCX_IO.html)
- [IMG_LoadPNG_IO](IMG_LoadPNG_IO.html)
- [IMG_LoadPNM_IO](IMG_LoadPNM_IO.html)
- [IMG_LoadQOI_IO](IMG_LoadQOI_IO.html)
- [IMG_LoadSVG_IO](IMG_LoadSVG_IO.html)
- [IMG_LoadTIF_IO](IMG_LoadTIF_IO.html)
- [IMG_LoadWEBP_IO](IMG_LoadWEBP_IO.html)
- [IMG_LoadXCF_IO](IMG_LoadXCF_IO.html)
- [IMG_LoadXPM_IO](IMG_LoadXPM_IO.html)
- [IMG_LoadXV_IO](IMG_LoadXV_IO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
