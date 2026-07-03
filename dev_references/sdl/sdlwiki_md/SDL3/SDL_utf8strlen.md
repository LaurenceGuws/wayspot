# SDL_utf8strlen

Count the number of codepoints in a UTF-8 string.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
size_t SDL_utf8strlen(const char *str);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **str** | The null-terminated UTF-8 string to read. Must not be NULL. |

## Return Value

(size_t) Returns The length (in codepoints, excluding the null
terminator) of `src`.

## Remarks

Counts the *codepoints*, not *bytes*, in `str`, excluding the null
terminator.

If you need to count the bytes in a string instead, consider using
[SDL_strlen](SDL_strlen.html)().

Since this handles Unicode, it expects the strings to be well-formed
UTF-8 and not a null-terminated string of arbitrary bytes. Bytes that
are not valid UTF-8 are treated as Unicode character U+FFFD (REPLACEMENT
CHARACTER), so a malformed or incomplete UTF-8 sequence might increase
the count by several replacement characters.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_utf8strnlen](SDL_utf8strnlen.html)
- [SDL_strlen](SDL_strlen.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
