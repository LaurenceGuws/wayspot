# SDL_HINT_AUDIO_DRIVER

A variable that specifies an audio backend to use.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_AUDIO_DRIVER "SDL_AUDIO_DRIVER"
```

</div>

## Remarks

By default, SDL will try all available audio backends in a reasonable
order until it finds one that can work, but this hint allows the app or
user to force a specific driver, such as "pipewire" if, say, you are on
PulseAudio but want to try talking to the lower level instead.

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
