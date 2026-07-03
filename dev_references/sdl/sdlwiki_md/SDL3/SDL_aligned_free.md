# SDL_aligned_free

Free memory allocated by [SDL_aligned_alloc](SDL_aligned_alloc.html)().

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_aligned_free(void *mem);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| void \* | **mem** | a pointer previously returned by [SDL_aligned_alloc](SDL_aligned_alloc.html)(), or NULL. |

## Remarks

The pointer is no longer valid after this call and cannot be
dereferenced anymore.

If `mem` is NULL, this function does nothing.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_aligned_alloc](SDL_aligned_alloc.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
