# SDL_CreateEnvironment

Create a set of environment variables

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Environment * SDL_CreateEnvironment(bool populated);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| bool | **populated** | true to initialize it from the C runtime environment, false to create an empty environment. |

## Return Value

([SDL_Environment](SDL_Environment.html) \*) Returns a pointer to the
new environment or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

If `populated` is false, it is safe to call this function from any
thread, otherwise it is safe if no other threads are calling setenv() or
unsetenv()

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetEnvironmentVariable](SDL_GetEnvironmentVariable.html)
- [SDL_GetEnvironmentVariables](SDL_GetEnvironmentVariables.html)
- [SDL_SetEnvironmentVariable](SDL_SetEnvironmentVariable.html)
- [SDL_UnsetEnvironmentVariable](SDL_UnsetEnvironmentVariable.html)
- [SDL_DestroyEnvironment](SDL_DestroyEnvironment.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
