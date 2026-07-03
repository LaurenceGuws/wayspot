# SDL_HINT_AUDIO_DISK_OUTPUT_FILE

Specify the output file when playing audio using the disk audio driver.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_AUDIO_DISK_OUTPUT_FILE "SDL_AUDIO_DISK_OUTPUT_FILE"
```

</div>

## Remarks

This defaults to "sdlaudio.raw"

This hint should be set before an audio device is opened.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
