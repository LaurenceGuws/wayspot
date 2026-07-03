# SDL_AudioStreamDataCompleteCallback

A callback that fires for completed
[SDL_PutAudioStreamDataNoCopy](SDL_PutAudioStreamDataNoCopy.html)()
data.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void (SDLCALL *SDL_AudioStreamDataCompleteCallback)(void *userdata, const void *buf, int buflen);
```

</div>

## Function Parameters

|  |  |
|----|----|
| **userdata** | an opaque pointer provided by the app for their personal use. |
| **buf** | the pointer provided to [SDL_PutAudioStreamDataNoCopy](SDL_PutAudioStreamDataNoCopy.html)(). |
| **buflen** | the size of buffer, in bytes, provided to [SDL_PutAudioStreamDataNoCopy](SDL_PutAudioStreamDataNoCopy.html)(). |

## Remarks

When using
[SDL_PutAudioStreamDataNoCopy](SDL_PutAudioStreamDataNoCopy.html)() to
provide data to an [SDL_AudioStream](SDL_AudioStream.html), it's not
safe to dispose of the data until the stream has completely consumed it.
Often times it's difficult to know exactly when this has happened.

This callback fires once when the stream no longer needs the buffer,
allowing the app to easily free or reuse it.

## Thread Safety

This callbacks may run from any thread, so if you need to protect shared
data, you should use [SDL_LockAudioStream](SDL_LockAudioStream.html) to
serialize access; this lock will be held before your callback is called,
so your callback does not need to manage the lock explicitly.

## Version

This datatype is available since SDL 3.4.0.

## See Also

- [SDL_SetAudioStreamGetCallback](SDL_SetAudioStreamGetCallback.html)
- [SDL_SetAudioStreamPutCallback](SDL_SetAudioStreamPutCallback.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryAudio](CategoryAudio.html)
