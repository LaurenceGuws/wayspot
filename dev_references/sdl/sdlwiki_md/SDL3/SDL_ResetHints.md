# SDL_ResetHints

Reset all hints to the default values.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_ResetHints(void);
```

</div>

## Remarks

This will reset all hints to the value of the associated environment
variable, or NULL if the environment isn't set. Callbacks will be called
normally with this change.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_ResetHint](SDL_ResetHint.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHints](CategoryHints.html)
