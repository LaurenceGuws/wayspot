# SDL_SetHintWithPriority

Set a hint with a specific priority.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetHintWithPriority(const char *name, const char *value, SDL_HintPriority priority);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **name** | the hint to set. |
| const char \* | **value** | the value of the hint variable. |
| [SDL_HintPriority](SDL_HintPriority.html) | **priority** | the [SDL_HintPriority](SDL_HintPriority.html) level for the hint. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The priority controls the behavior when setting a hint that already has
a value. Hints will replace existing hints of their priority and lower.
Environment variables are considered to have override priority.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetHint](SDL_GetHint.html)
- [SDL_ResetHint](SDL_ResetHint.html)
- [SDL_SetHint](SDL_SetHint.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHints](CategoryHints.html)
