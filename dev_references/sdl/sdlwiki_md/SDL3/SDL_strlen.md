# SDL_strlen

This works exactly like strlen() but doesn't require access to a C
runtime.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
size_t SDL_strlen(const char *str);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **str** | The null-terminated string to read. Must not be NULL. |

## Return Value

(size_t) Returns the length (in bytes, excluding the null terminator) of
`src`.

## Remarks

Counts the bytes in `str`, excluding the null terminator.

If you need the length of a UTF-8 string, consider using
[SDL_utf8strlen](SDL_utf8strlen.html)().

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_strnlen](SDL_strnlen.html)
- [SDL_utf8strlen](SDL_utf8strlen.html)
- [SDL_utf8strnlen](SDL_utf8strnlen.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
