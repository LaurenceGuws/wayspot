# SDL_getenv_unsafe

Get the value of a variable in the environment.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_getenv_unsafe(const char *name);
```

</div>

## Function Parameters

|               |          |                                  |
|---------------|----------|----------------------------------|
| const char \* | **name** | the name of the variable to get. |

## Return Value

(const char \*) Returns a pointer to the value of the variable or NULL
if it can't be found.

## Remarks

This function bypasses SDL's cached copy of the environment and is not
thread-safe.

## Thread Safety

This function is not thread safe, consider using
[SDL_getenv](SDL_getenv.html)() instead.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_getenv](SDL_getenv.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
