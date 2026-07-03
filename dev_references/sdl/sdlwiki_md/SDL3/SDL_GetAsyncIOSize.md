# SDL_GetAsyncIOSize

Use this function to get the size of the data stream in an
[SDL_AsyncIO](SDL_AsyncIO.html).

## Header File

Defined in
[\<SDL3/SDL_asyncio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_asyncio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Sint64 SDL_GetAsyncIOSize(SDL_AsyncIO *asyncio);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AsyncIO](SDL_AsyncIO.html) \* | **asyncio** | the [SDL_AsyncIO](SDL_AsyncIO.html) to get the size of the data stream from. |

## Return Value

([Sint64](Sint64.html)) Returns the size of the data stream in the
[SDL_IOStream](SDL_IOStream.html) on success or a negative error code on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This call is *not* asynchronous; it assumes that obtaining this info is
a non-blocking operation in most reasonable cases.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAsyncIO](CategoryAsyncIO.html)
