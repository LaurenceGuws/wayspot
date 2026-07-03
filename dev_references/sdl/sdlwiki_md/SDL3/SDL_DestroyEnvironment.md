# SDL_DestroyEnvironment

Destroy a set of environment variables.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyEnvironment(SDL_Environment *env);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Environment](SDL_Environment.html) \* | **env** | the environment to destroy. |

## Thread Safety

It is safe to call this function from any thread, as long as the
environment is no longer in use.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateEnvironment](SDL_CreateEnvironment.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
