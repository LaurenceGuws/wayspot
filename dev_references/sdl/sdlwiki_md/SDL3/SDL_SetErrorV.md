# SDL_SetErrorV

Set the SDL error message for the current thread.

## Header File

Defined in
[\<SDL3/SDL_error.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_error.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetErrorV(const char *fmt, va_list ap);
```

</div>

## Function Parameters

|               |         |                                         |
|---------------|---------|-----------------------------------------|
| const char \* | **fmt** | a printf()-style message format string. |
| va_list       | **ap**  | a variable argument list.               |

## Return Value

(bool) Returns false.

## Remarks

Calling this function will replace any previous error message that was
set.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_ClearError](SDL_ClearError.html)
- [SDL_GetError](SDL_GetError.html)
- [SDL_SetError](SDL_SetError.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryError](CategoryError.html)
