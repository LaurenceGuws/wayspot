# SDL_GetSandbox

Get the application sandbox environment, if any.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Sandbox SDL_GetSandbox(void);
```

</div>

## Return Value

([SDL_Sandbox](SDL_Sandbox.html)) Returns the application sandbox
environment or [SDL_SANDBOX_NONE](SDL_SANDBOX_NONE.html) if the
application is not running in a sandbox environment.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
