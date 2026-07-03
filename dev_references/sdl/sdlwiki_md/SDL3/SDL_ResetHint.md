# SDL_ResetHint

Reset a hint to the default value.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_ResetHint(const char *name);
```

</div>

## Function Parameters

|               |          |                  |
|---------------|----------|------------------|
| const char \* | **name** | the hint to set. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This will reset a hint to the value of the environment variable, or NULL
if the environment isn't set. Callbacks will be called normally with
this change.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetHint](SDL_SetHint.html)
- [SDL_ResetHints](SDL_ResetHints.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHints](CategoryHints.html)
