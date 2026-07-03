# SDL_BindAudioStream

Bind a single audio stream to an audio device.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_BindAudioStream(SDL_AudioDeviceID devid, SDL_AudioStream *stream);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AudioDeviceID](SDL_AudioDeviceID.html) | **devid** | an audio device to bind a stream to. |
| [SDL_AudioStream](SDL_AudioStream.html) \* | **stream** | an audio stream to bind to a device. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This is a convenience function, equivalent to calling
`SDL_BindAudioStreams(devid, &stream, 1)`.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_BindAudioStreams](SDL_BindAudioStreams.html)
- [SDL_UnbindAudioStream](SDL_UnbindAudioStream.html)
- [SDL_GetAudioStreamDevice](SDL_GetAudioStreamDevice.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAudio](CategoryAudio.html)
