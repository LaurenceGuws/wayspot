# SDL_stack_free

Free memory previously allocated with
[SDL_stack_alloc](SDL_stack_alloc.html).

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_stack_free(data)
```

</div>

## Macro Parameters

|  |  |
|----|----|
| **data** | the pointer, from [SDL_stack_alloc](SDL_stack_alloc.html)(), to free. |

## Remarks

If SDL used alloca() to allocate this memory, this macro does nothing
and the allocated memory will be automatically released when the
function that called [SDL_stack_alloc](SDL_stack_alloc.html)() returns.
If SDL used [SDL_malloc](SDL_malloc.html)(), it will
[SDL_free](SDL_free.html) the memory immediately.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_stack_alloc](SDL_stack_alloc.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
