# SDL_unsetenv_unsafe

Clear a variable from the environment.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_unsetenv_unsafe(const char *name);
```

</div>

## Function Parameters

|               |          |                                    |
|---------------|----------|------------------------------------|
| const char \* | **name** | the name of the variable to unset. |

## Return Value

(int) Returns 0 on success, -1 on error.

## Thread Safety

This function is not thread safe, consider using
[SDL_UnsetEnvironmentVariable](SDL_UnsetEnvironmentVariable.html)()
instead.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_UnsetEnvironmentVariable](SDL_UnsetEnvironmentVariable.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
