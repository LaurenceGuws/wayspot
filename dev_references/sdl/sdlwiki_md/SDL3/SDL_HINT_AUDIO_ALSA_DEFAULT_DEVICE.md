# SDL_HINT_AUDIO_ALSA_DEFAULT_DEVICE

Specify the default ALSA audio device name.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_AUDIO_ALSA_DEFAULT_DEVICE "SDL_AUDIO_ALSA_DEFAULT_DEVICE"
```

</div>

## Remarks

This variable is a specific audio device to open when the "default"
audio device is used.

This hint will be ignored when opening the default playback device if
[SDL_HINT_AUDIO_ALSA_DEFAULT_PLAYBACK_DEVICE](SDL_HINT_AUDIO_ALSA_DEFAULT_PLAYBACK_DEVICE.html)
is set, or when opening the default recording device if
[SDL_HINT_AUDIO_ALSA_DEFAULT_RECORDING_DEVICE](SDL_HINT_AUDIO_ALSA_DEFAULT_RECORDING_DEVICE.html)
is set.

This hint should be set before an audio device is opened.

## Version

This hint is available since SDL 3.2.0.

## See Also

- [SDL_HINT_AUDIO_ALSA_DEFAULT_PLAYBACK_DEVICE](SDL_HINT_AUDIO_ALSA_DEFAULT_PLAYBACK_DEVICE.html)
- [SDL_HINT_AUDIO_ALSA_DEFAULT_RECORDING_DEVICE](SDL_HINT_AUDIO_ALSA_DEFAULT_RECORDING_DEVICE.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
