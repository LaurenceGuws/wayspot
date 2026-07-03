# SDL_realloc

Change the size of allocated memory.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void * SDL_realloc(void *mem, size_t size);
```

</div>

## Function Parameters

|         |          |                                                       |
|---------|----------|-------------------------------------------------------|
| void \* | **mem**  | a pointer to allocated memory to reallocate, or NULL. |
| size_t  | **size** | the new size of the memory.                           |

## Return Value

(void \*) Returns a pointer to the newly allocated memory, or NULL if
allocation failed.

## Remarks

The memory returned by this function must be freed with
[SDL_free](SDL_free.html)().

If `size` is 0, it will be set to 1. Note that this is unlike some other
C runtime `realloc` implementations, which may treat `realloc(mem, 0)`
the same way as `free(mem)`.

If `mem` is NULL, the behavior of this function is equivalent to
[SDL_malloc](SDL_malloc.html)(). Otherwise, the function can have one of
three possible outcomes:

- If it returns the same pointer as `mem`, it means that `mem` was
  resized in place without freeing.
- If it returns a different non-NULL pointer, it means that `mem` was
  freed and cannot be dereferenced anymore.
- If it returns NULL (indicating failure), then `mem` will remain valid
  and must still be freed with [SDL_free](SDL_free.html)().

If the allocation is successfully resized, the returned pointer is
guaranteed to be aligned to either the *fundamental alignment*
(`alignof(max_align_t)` in C11 and later) or `2 * sizeof(void *)`,
whichever is smaller.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_free](SDL_free.html)
- [SDL_malloc](SDL_malloc.html)
- [SDL_calloc](SDL_calloc.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
