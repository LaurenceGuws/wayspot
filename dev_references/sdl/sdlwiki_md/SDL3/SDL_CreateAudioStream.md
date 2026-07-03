# SDL_CreateAudioStream

Create a new audio stream.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_AudioStream * SDL_CreateAudioStream(const SDL_AudioSpec *src_spec, const SDL_AudioSpec *dst_spec);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_AudioSpec](SDL_AudioSpec.html) \* | **src_spec** | the format details of the input audio. |
| const [SDL_AudioSpec](SDL_AudioSpec.html) \* | **dst_spec** | the format details of the output audio. |

## Return Value

([SDL_AudioStream](SDL_AudioStream.html) \*) Returns a new audio stream
on success or NULL on failure; call [SDL_GetError](SDL_GetError.html)()
for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_PutAudioStreamData](SDL_PutAudioStreamData.html)
- [SDL_GetAudioStreamData](SDL_GetAudioStreamData.html)
- [SDL_GetAudioStreamAvailable](SDL_GetAudioStreamAvailable.html)
- [SDL_FlushAudioStream](SDL_FlushAudioStream.html)
- [SDL_ClearAudioStream](SDL_ClearAudioStream.html)
- [SDL_SetAudioStreamFormat](SDL_SetAudioStreamFormat.html)
- [SDL_DestroyAudioStream](SDL_DestroyAudioStream.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAudio](CategoryAudio.html)
