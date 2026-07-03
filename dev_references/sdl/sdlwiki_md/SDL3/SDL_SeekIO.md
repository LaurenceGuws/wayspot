# SDL_SeekIO

Seek within an [SDL_IOStream](SDL_IOStream.html) data stream.

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Sint64 SDL_SeekIO(SDL_IOStream *context, Sint64 offset, SDL_IOWhence whence);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_IOStream](SDL_IOStream.html) \* | **context** | a pointer to an [SDL_IOStream](SDL_IOStream.html) structure. |
| [Sint64](Sint64.html) | **offset** | an offset in bytes, relative to `whence` location; can be negative. |
| [SDL_IOWhence](SDL_IOWhence.html) | **whence** | any of [`SDL_IO_SEEK_SET`](SDL_IO_SEEK_SET.html), [`SDL_IO_SEEK_CUR`](SDL_IO_SEEK_CUR.html), [`SDL_IO_SEEK_END`](SDL_IO_SEEK_END.html). |

## Return Value

([Sint64](Sint64.html)) Returns the final offset in the data stream
after the seek or -1 on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function seeks to byte `offset`, relative to `whence`.

`whence` may be any of the following values:

- [`SDL_IO_SEEK_SET`](SDL_IO_SEEK_SET.html): seek from the beginning of
  data
- [`SDL_IO_SEEK_CUR`](SDL_IO_SEEK_CUR.html): seek relative to current
  read point
- [`SDL_IO_SEEK_END`](SDL_IO_SEEK_END.html): seek relative to the end of
  data

If this stream can not seek, it will return -1.

## Thread Safety

Do not use the same [SDL_IOStream](SDL_IOStream.html) from two threads
at once.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_TellIO](SDL_TellIO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
