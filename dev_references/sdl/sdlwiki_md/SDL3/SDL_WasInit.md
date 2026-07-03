# SDL_WasInit

Get a mask of the specified subsystems which are currently initialized.

## Header File

Defined in
[\<SDL3/SDL_init.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_init.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_InitFlags SDL_WasInit(SDL_InitFlags flags);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_InitFlags](SDL_InitFlags.html) | **flags** | any of the flags used by [SDL_Init](SDL_Init.html)(); see [SDL_Init](SDL_Init.html) for details. |

## Return Value

([SDL_InitFlags](SDL_InitFlags.html)) Returns a mask of all initialized
subsystems if `flags` is 0, otherwise it returns the initialization
status of the specified subsystems.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_Init](SDL_Init.html)
- [SDL_InitSubSystem](SDL_InitSubSystem.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryInit](CategoryInit.html)
