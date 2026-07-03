# SDL_AddHintCallback

Add a function to watch a particular hint.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_AddHintCallback(const char *name, SDL_HintCallback callback, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **name** | the hint to watch. |
| [SDL_HintCallback](SDL_HintCallback.html) | **callback** | An [SDL_HintCallback](SDL_HintCallback.html) function that will be called when the hint value changes. |
| void \* | **userdata** | a pointer to pass to the callback function. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The callback function is called *during* this function, to provide it an
initial value, and again each time the hint's value changes.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_RemoveHintCallback](SDL_RemoveHintCallback.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHints](CategoryHints.html)
