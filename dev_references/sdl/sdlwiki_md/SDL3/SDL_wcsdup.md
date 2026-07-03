# SDL_wcsdup

Allocate a copy of a wide string.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
wchar_t * SDL_wcsdup(const wchar_t *wstr);
```

</div>

## Function Parameters

|                  |          |                     |
|------------------|----------|---------------------|
| const wchar_t \* | **wstr** | the string to copy. |

## Return Value

(wchar_t \*) Returns a pointer to the newly-allocated wide string.

## Remarks

This allocates enough space for a null-terminated copy of `wstr`, using
[SDL_malloc](SDL_malloc.html), and then makes a copy of the string into
this space.

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
