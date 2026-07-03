# SDL_IOFromDynamicMem

Use this function to create an [SDL_IOStream](SDL_IOStream.html) that is
backed by dynamically allocated memory.

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_IOStream * SDL_IOFromDynamicMem(void);
```

</div>

## Return Value

([SDL_IOStream](SDL_IOStream.html) \*) Returns a pointer to a new
[SDL_IOStream](SDL_IOStream.html) structure or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This supports the following properties to provide access to the memory
and control over allocations:

- [`SDL_PROP_IOSTREAM_DYNAMIC_MEMORY_POINTER`](SDL_PROP_IOSTREAM_DYNAMIC_MEMORY_POINTER.html):
  a pointer to the internal memory of the stream. This can be set to
  NULL to transfer ownership of the memory to the application, which
  should free the memory with [SDL_free](SDL_free.html)(). If this is
  done, the next operation on the stream must be
  [SDL_CloseIO](SDL_CloseIO.html)().
- [`SDL_PROP_IOSTREAM_DYNAMIC_CHUNKSIZE_NUMBER`](SDL_PROP_IOSTREAM_DYNAMIC_CHUNKSIZE_NUMBER.html):
  memory will be allocated in multiples of this size, defaulting to
  1024.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseIO](SDL_CloseIO.html)
- [SDL_ReadIO](SDL_ReadIO.html)
- [SDL_SeekIO](SDL_SeekIO.html)
- [SDL_TellIO](SDL_TellIO.html)
- [SDL_WriteIO](SDL_WriteIO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryIOStream](CategoryIOStream.html)
