# SDL_ClearError

Clear any previous error message for this thread.

## Header File

Defined in
[\<SDL3/SDL_error.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_error.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_ClearError(void);
```

</div>

## Return Value

(bool) Returns true.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
const char *error = SDL_GetError();
if (*error) {
  SDL_Log("SDL error: %s", error);
  SDL_ClearError();
}
```

</div>

## See Also

- [SDL_GetError](SDL_GetError.html)
- [SDL_SetError](SDL_SetError.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryError](CategoryError.html)
