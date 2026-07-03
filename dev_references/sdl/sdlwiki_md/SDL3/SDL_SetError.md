# SDL_SetError

Set the SDL error message for the current thread.

## Header File

Defined in
[\<SDL3/SDL_error.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_error.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetError(const char *fmt, ...);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **fmt** | a printf()-style message format string. |
| ... | **...** | additional parameters matching % tokens in the `fmt` string, if any. |

## Return Value

(bool) Returns false.

## Remarks

Calling this function will replace any previous error message that was
set.

This function always returns false, since SDL frequently uses false to
signify a failing result, leading to this idiom:

<div id="cb2" class="sourceCode">

``` sourceCode
if (error_code) {
    return SDL_SetError("This operation has failed: %d", error_code);
}
```

</div>

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_ClearError](SDL_ClearError.html)
- [SDL_GetError](SDL_GetError.html)
- [SDL_SetErrorV](SDL_SetErrorV.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryError](CategoryError.html)
