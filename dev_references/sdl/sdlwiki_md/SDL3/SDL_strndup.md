# SDL_strndup

Allocate a copy of a string, up to n characters.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
char * SDL_strndup(const char *str, size_t maxlen);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **str** | the string to copy. |
| size_t | **maxlen** | the maximum length of the copied string, not counting the null-terminator character. |

## Return Value

(char \*) Returns a pointer to the newly-allocated string.

## Remarks

This allocates enough space for a null-terminated copy of `str`, up to
`maxlen` bytes, using [SDL_malloc](SDL_malloc.html), and then makes a
copy of the string into this space.

If the string is longer than `maxlen` bytes, the returned string will be
`maxlen` bytes long, plus a null-terminator character that isn't
included in the count.

The returned string is owned by the caller, and should be passed to
[SDL_free](SDL_free.html) when no longer needed.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
