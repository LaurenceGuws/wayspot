# SDL_CameraSpec

The details of an output format for a camera device.

## Header File

Defined in
[\<SDL3/SDL_camera.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_camera.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_CameraSpec
{
    SDL_PixelFormat format;     /**< Frame format */
    SDL_Colorspace colorspace;  /**< Frame colorspace */
    int width;                  /**< Frame width */
    int height;                 /**< Frame height */
    int framerate_numerator;     /**< Frame rate numerator ((num / denom) == FPS, (denom / num) == duration in seconds) */
    int framerate_denominator;   /**< Frame rate denominator ((num / denom) == FPS, (denom / num) == duration in seconds) */
} SDL_CameraSpec;
```

</div>

## Remarks

Cameras often support multiple formats; each one will be encapsulated in
this struct.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_GetCameraSupportedFormats](SDL_GetCameraSupportedFormats.html)
- [SDL_GetCameraFormat](SDL_GetCameraFormat.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryCamera](CategoryCamera.html)
