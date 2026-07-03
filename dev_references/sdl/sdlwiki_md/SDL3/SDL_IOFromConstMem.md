# SDL_IOFromConstMem

Use this function to prepare a read-only memory buffer for use with
[SDL_IOStream](SDL_IOStream.html).

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_IOStream * SDL_IOFromConstMem(const void *mem, size_t size);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const void \* | **mem** | a pointer to a read-only buffer to feed an [SDL_IOStream](SDL_IOStream.html) stream. |
| size_t | **size** | the buffer size, in bytes. |

## Return Value

([SDL_IOStream](SDL_IOStream.html) \*) Returns a pointer to a new
[SDL_IOStream](SDL_IOStream.html) structure or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function sets up an [SDL_IOStream](SDL_IOStream.html) struct based
on a memory area of a certain size. It assumes the memory area is not
writable.

Attempting to write to this [SDL_IOStream](SDL_IOStream.html) stream
will report an error without writing to the memory buffer.

This memory buffer is not copied by the
[SDL_IOStream](SDL_IOStream.html); the pointer you provide must remain
valid until you close the stream.

If you need to write to a memory buffer, you should use
[SDL_IOFromMem](SDL_IOFromMem.html)() with a writable buffer of memory
instead.

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

- [SDL_IOFromMem](SDL_IOFromMem.html)
- [SDL_CloseIO](SDL_CloseIO.html)
- [SDL_ReadIO](SDL_ReadIO.html)
- [SDL_SeekIO](SDL_SeekIO.html)
- [SDL_TellIO](SDL_TellIO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
