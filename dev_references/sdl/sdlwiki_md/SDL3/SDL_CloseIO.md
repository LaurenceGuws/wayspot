# SDL_CloseIO

Close and free an allocated [SDL_IOStream](SDL_IOStream.html) structure.

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_CloseIO(SDL_IOStream *context);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_IOStream](SDL_IOStream.html) \* | **context** | [SDL_IOStream](SDL_IOStream.html) structure to close. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

[SDL_CloseIO](SDL_CloseIO.html)() closes and cleans up the
[SDL_IOStream](SDL_IOStream.html) stream. It releases any resources used
by the stream and frees the [SDL_IOStream](SDL_IOStream.html) itself.
This returns true on success, or false if the stream failed to flush to
its output (e.g. to disk).

Note that if this fails to flush the stream for any reason, this
function reports an error, but the [SDL_IOStream](SDL_IOStream.html) is
still invalid once this function returns.

This call flushes any buffered writes to the operating system, but there
are no guarantees that those writes have gone to physical media; they
might be in the OS's file cache, waiting to go to disk later. If it's
absolutely crucial that writes go to disk immediately, so they are
definitely stored even if the power fails before the file cache would
have caught up, one should call [SDL_FlushIO](SDL_FlushIO.html)() before
closing. Note that flushing takes time and makes the system and your app
operate less efficiently, so do so sparingly.

## Thread Safety

Do not use the same [SDL_IOStream](SDL_IOStream.html) from two threads
at once.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_OpenIO](SDL_OpenIO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
