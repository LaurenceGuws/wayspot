# SDL_GetIOStatus

Query the stream status of an [SDL_IOStream](SDL_IOStream.html).

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_IOStatus SDL_GetIOStatus(SDL_IOStream *context);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_IOStream](SDL_IOStream.html) \* | **context** | the [SDL_IOStream](SDL_IOStream.html) to query. |

## Return Value

([SDL_IOStatus](SDL_IOStatus.html)) Returns an
[SDL_IOStatus](SDL_IOStatus.html) enum with the current state.

## Remarks

This information can be useful to decide if a short read or write was
due to an error, an EOF, or a non-blocking operation that isn't yet
ready to complete.

An [SDL_IOStream](SDL_IOStream.html)'s status is only expected to change
after a [SDL_ReadIO](SDL_ReadIO.html) or [SDL_WriteIO](SDL_WriteIO.html)
call; don't expect it to change if you just call this query function in
a tight loop.

## Thread Safety

Do not use the same [SDL_IOStream](SDL_IOStream.html) from two threads
at once.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
