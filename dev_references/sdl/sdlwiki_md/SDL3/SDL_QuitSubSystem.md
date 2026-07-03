# SDL_QuitSubSystem

Shut down specific SDL subsystems.

## Header File

Defined in
[\<SDL3/SDL_init.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_init.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_QuitSubSystem(SDL_InitFlags flags);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_InitFlags](SDL_InitFlags.html) | **flags** | any of the flags used by [SDL_Init](SDL_Init.html)(); see [SDL_Init](SDL_Init.html) for details. |

## Remarks

You still need to call [SDL_Quit](SDL_Quit.html)() even if you close all
open subsystems with [SDL_QuitSubSystem](SDL_QuitSubSystem.html)().

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_InitSubSystem](SDL_InitSubSystem.html)
- [SDL_Quit](SDL_Quit.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryInit](CategoryInit.html)
