# SDL_DisplayMode

The structure that defines a display mode.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_DisplayMode
{
    SDL_DisplayID displayID;        /**< the display this mode is associated with */
    SDL_PixelFormat format;         /**< pixel format */
    int w;                          /**< width */
    int h;                          /**< height */
    float pixel_density;            /**< scale converting size to pixels (e.g. a 1920x1080 mode with 2.0 scale would have 3840x2160 pixels) */
    float refresh_rate;             /**< refresh rate (or 0.0f for unspecified) */
    int refresh_rate_numerator;     /**< precise refresh rate numerator (or 0 for unspecified) */
    int refresh_rate_denominator;   /**< precise refresh rate denominator */

    SDL_DisplayModeData *internal;  /**< Private */

} SDL_DisplayMode;
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_GetFullscreenDisplayModes](SDL_GetFullscreenDisplayModes.html)
- [SDL_GetDesktopDisplayMode](SDL_GetDesktopDisplayMode.html)
- [SDL_GetCurrentDisplayMode](SDL_GetCurrentDisplayMode.html)
- [SDL_SetWindowFullscreenMode](SDL_SetWindowFullscreenMode.html)
- [SDL_GetWindowFullscreenMode](SDL_GetWindowFullscreenMode.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryVideo](CategoryVideo.html)
