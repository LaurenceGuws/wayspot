# SDL_AudioStreamDevicePaused

Use this function to query if an audio device associated with a stream
is paused.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_AudioStreamDevicePaused(SDL_AudioStream *stream);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AudioStream](SDL_AudioStream.html) \* | **stream** | the audio stream associated with the audio device to query. |

## Return Value

(bool) Returns true if device is valid and paused, false otherwise.

## Remarks

Unlike in SDL2, audio devices start in an *unpaused* state, since an app
has to bind a stream before any audio will flow.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_PauseAudioStreamDevice](SDL_PauseAudioStreamDevice.html)
- [SDL_ResumeAudioStreamDevice](SDL_ResumeAudioStreamDevice.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAudio](CategoryAudio.html)
