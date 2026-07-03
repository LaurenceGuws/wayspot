# SDL_SaveFile_IO

Save all the data into an SDL data stream.

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SaveFile_IO(SDL_IOStream *src, const void *data, size_t datasize, bool closeio);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_IOStream](SDL_IOStream.html) \* | **src** | the [SDL_IOStream](SDL_IOStream.html) to write all data to. |
| const void \* | **data** | the data to be written. If datasize is 0, may be NULL or a invalid pointer. |
| size_t | **datasize** | the number of bytes to be written. |
| bool | **closeio** | if true, calls [SDL_CloseIO](SDL_CloseIO.html)() on `src` before returning, even in the case of an error. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

Do not use the same [SDL_IOStream](SDL_IOStream.html) from two threads
at once.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SaveFile](SDL_SaveFile.html)
- [SDL_LoadFile_IO](SDL_LoadFile_IO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
