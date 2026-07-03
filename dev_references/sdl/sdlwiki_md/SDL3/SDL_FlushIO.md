# SDL_FlushIO

Flush any buffered data in the stream.

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_FlushIO(SDL_IOStream *context);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_IOStream](SDL_IOStream.html) \* | **context** | [SDL_IOStream](SDL_IOStream.html) structure to flush. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function makes sure that any buffered data is written to the
stream. Normally this isn't necessary but if the stream is a pipe or
socket it guarantees that any pending data is sent.

## Thread Safety

Do not use the same [SDL_IOStream](SDL_IOStream.html) from two threads
at once.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_OpenIO](SDL_OpenIO.html)
- [SDL_WriteIO](SDL_WriteIO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
