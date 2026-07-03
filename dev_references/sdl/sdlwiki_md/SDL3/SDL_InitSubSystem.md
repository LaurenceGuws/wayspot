# SDL_InitSubSystem

Compatibility function to initialize the SDL library.

## Header File

Defined in
[\<SDL3/SDL_init.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_init.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_InitSubSystem(SDL_InitFlags flags);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_InitFlags](SDL_InitFlags.html) | **flags** | any of the flags used by [SDL_Init](SDL_Init.html)(); see [SDL_Init](SDL_Init.html) for details. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function and [SDL_Init](SDL_Init.html)() are interchangeable.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_Init](SDL_Init.html)
- [SDL_Quit](SDL_Quit.html)
- [SDL_QuitSubSystem](SDL_QuitSubSystem.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryInit](CategoryInit.html)
