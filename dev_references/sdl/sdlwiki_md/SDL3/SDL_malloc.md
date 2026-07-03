# SDL_malloc

Allocate uninitialized memory.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void * SDL_malloc(size_t size);
```

</div>

## Function Parameters

|        |          |                       |
|--------|----------|-----------------------|
| size_t | **size** | the size to allocate. |

## Return Value

(void \*) Returns a pointer to the allocated memory, or NULL if
allocation failed.

## Remarks

The allocated memory returned by this function must be freed with
[SDL_free](SDL_free.html)().

If `size` is 0, it will be set to 1.

If the allocation is successful, the returned pointer is guaranteed to
be aligned to either the *fundamental alignment* (`alignof(max_align_t)`
in C11 and later) or `2 * sizeof(void *)`, whichever is smaller. Use
[SDL_aligned_alloc](SDL_aligned_alloc.html)() if you need to allocate
memory aligned to an alignment greater than this guarantee.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_free](SDL_free.html)
- [SDL_calloc](SDL_calloc.html)
- [SDL_realloc](SDL_realloc.html)
- [SDL_aligned_alloc](SDL_aligned_alloc.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
