# SDL_GetIOSize

Use this function to get the size of the data stream in an
[SDL_IOStream](SDL_IOStream.html).

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Sint64 SDL_GetIOSize(SDL_IOStream *context);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_IOStream](SDL_IOStream.html) \* | **context** | the [SDL_IOStream](SDL_IOStream.html) to get the size of the data stream from. |

## Return Value

([Sint64](Sint64.html)) Returns the size of the data stream in the
[SDL_IOStream](SDL_IOStream.html) on success or a negative error code on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

Do not use the same [SDL_IOStream](SDL_IOStream.html) from two threads
at once.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
