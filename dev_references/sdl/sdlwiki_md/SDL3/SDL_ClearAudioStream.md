# SDL_ClearAudioStream

Clear any pending data in the stream.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_ClearAudioStream(SDL_AudioStream *stream);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AudioStream](SDL_AudioStream.html) \* | **stream** | the audio stream to clear. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This drops any queued data, so there will be nothing to read from the
stream until more is added.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetAudioStreamAvailable](SDL_GetAudioStreamAvailable.html)
- [SDL_GetAudioStreamData](SDL_GetAudioStreamData.html)
- [SDL_GetAudioStreamQueued](SDL_GetAudioStreamQueued.html)
- [SDL_PutAudioStreamData](SDL_PutAudioStreamData.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAudio](CategoryAudio.html)
