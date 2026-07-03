# SDL_GetEnvironment

Get the process environment.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Environment * SDL_GetEnvironment(void);
```

</div>

## Return Value

([SDL_Environment](SDL_Environment.html) \*) Returns a pointer to the
environment for the process or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This is initialized at application start and is not affected by setenv()
and unsetenv() calls after that point. Use
[SDL_SetEnvironmentVariable](SDL_SetEnvironmentVariable.html)() and
[SDL_UnsetEnvironmentVariable](SDL_UnsetEnvironmentVariable.html)() if
you want to modify this environment, or
[SDL_setenv_unsafe](SDL_setenv_unsafe.html)() or
[SDL_unsetenv_unsafe](SDL_unsetenv_unsafe.html)() if you want changes to
persist in the C runtime environment after [SDL_Quit](SDL_Quit.html)().

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetEnvironmentVariable](SDL_GetEnvironmentVariable.html)
- [SDL_GetEnvironmentVariables](SDL_GetEnvironmentVariables.html)
- [SDL_SetEnvironmentVariable](SDL_SetEnvironmentVariable.html)
- [SDL_UnsetEnvironmentVariable](SDL_UnsetEnvironmentVariable.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
