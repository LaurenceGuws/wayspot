# SDL_IOprintf

Print to an [SDL_IOStream](SDL_IOStream.html) data stream.

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
size_t SDL_IOprintf(SDL_IOStream *context, const char *fmt, ...);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_IOStream](SDL_IOStream.html) \* | **context** | a pointer to an [SDL_IOStream](SDL_IOStream.html) structure. |
| const char \* | **fmt** | a printf() style format string. |
| ... | **...** | additional parameters matching % tokens in the `fmt` string, if any. |

## Return Value

(size_t) Returns the number of bytes written or 0 on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function does formatted printing to the stream.

## Thread Safety

Do not use the same [SDL_IOStream](SDL_IOStream.html) from two threads
at once.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_IOvprintf](SDL_IOvprintf.html)
- [SDL_WriteIO](SDL_WriteIO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
