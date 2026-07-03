# SDL_WriteS16LE

Use this function to write 16 bits in native format to an
[SDL_IOStream](SDL_IOStream.html) as little-endian data.

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_WriteS16LE(SDL_IOStream *dst, Sint16 value);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_IOStream](SDL_IOStream.html) \* | **dst** | the stream to which data will be written. |
| [Sint16](Sint16.html) | **value** | the data to be written, in native format. |

## Return Value

(bool) Returns true on successful write or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

SDL byteswaps the data only if necessary, so the application always
specifies native format, and the data written will be in little-endian
format.

## Thread Safety

Do not use the same [SDL_IOStream](SDL_IOStream.html) from two threads
at once.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
