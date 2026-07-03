# SDL_FlashOperation

Window flash operation.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_FlashOperation
{
    SDL_FLASH_CANCEL,                   /**< Cancel any window flash state */
    SDL_FLASH_BRIEFLY,                  /**< Flash the window briefly to get attention */
    SDL_FLASH_UNTIL_FOCUSED             /**< Flash the window until it gets focus */
} SDL_FlashOperation;
```

</div>

## Version

This enum is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html),
[CategoryVideo](CategoryVideo.html)
