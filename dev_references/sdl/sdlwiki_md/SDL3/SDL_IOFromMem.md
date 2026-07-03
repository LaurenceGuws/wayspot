# SDL_IOFromMem

Use this function to prepare a read-write memory buffer for use with
[SDL_IOStream](SDL_IOStream.html).

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_IOStream * SDL_IOFromMem(void *mem, size_t size);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| void \* | **mem** | a pointer to a buffer to feed an [SDL_IOStream](SDL_IOStream.html) stream. |
| size_t | **size** | the buffer size, in bytes. |

## Return Value

([SDL_IOStream](SDL_IOStream.html) \*) Returns a pointer to a new
[SDL_IOStream](SDL_IOStream.html) structure or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function sets up an [SDL_IOStream](SDL_IOStream.html) struct based
on a memory area of a certain size, for both read and write access.

This memory buffer is not copied by the
[SDL_IOStream](SDL_IOStream.html); the pointer you provide must remain
valid until you close the stream.

If you need to make sure the [SDL_IOStream](SDL_IOStream.html) never
writes to the memory buffer, you should use
[SDL_IOFromConstMem](SDL_IOFromConstMem.html)() with a read-only buffer
of memory instead.

The following properties will be set at creation time by SDL:

- [`SDL_PROP_IOSTREAM_MEMORY_POINTER`](SDL_PROP_IOSTREAM_MEMORY_POINTER.html):
  this will be the `mem` parameter that was passed to this function.
- [`SDL_PROP_IOSTREAM_MEMORY_SIZE_NUMBER`](SDL_PROP_IOSTREAM_MEMORY_SIZE_NUMBER.html):
  this will be the `size` parameter that was passed to this function.

Additionally, the following properties are recognized:

- [`SDL_PROP_IOSTREAM_MEMORY_FREE_FUNC_POINTER`](SDL_PROP_IOSTREAM_MEMORY_FREE_FUNC_POINTER.html):
  if this property is set to a non-NULL value it will be interpreted as
  a function of [SDL_free_func](SDL_free_func.html) type and called with
  the passed `mem` pointer when closing the stream. By default it is
  unset, i.e., the memory will not be freed.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_IOFromConstMem](SDL_IOFromConstMem.html)
- [SDL_CloseIO](SDL_CloseIO.html)
- [SDL_FlushIO](SDL_FlushIO.html)
- [SDL_ReadIO](SDL_ReadIO.html)
- [SDL_SeekIO](SDL_SeekIO.html)
- [SDL_TellIO](SDL_TellIO.html)
- [SDL_WriteIO](SDL_WriteIO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
