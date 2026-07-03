# SDL_UnlockAudioStream

Unlock an audio stream for serialized access.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_UnlockAudioStream(SDL_AudioStream *stream);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AudioStream](SDL_AudioStream.html) \* | **stream** | the audio stream to unlock. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This unlocks an audio stream after a call to
[SDL_LockAudioStream](SDL_LockAudioStream.html).

## Thread Safety

You should only call this from the same thread that previously called
[SDL_LockAudioStream](SDL_LockAudioStream.html).

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_LockAudioStream](SDL_LockAudioStream.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAudio](CategoryAudio.html)
