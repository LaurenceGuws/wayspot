# SDL_RunApp

Initializes and launches an SDL application, by doing platform-specific
initialization before calling your mainFunction and cleanups after it
returns, if that is needed for a specific platform, otherwise it just
calls mainFunction.

## Header File

Defined in
[\<SDL3/SDL_main.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_main.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_RunApp(int argc, char *argv[], SDL_main_func mainFunction, void *reserved);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int | **argc** | the argc parameter from the application's main() function, or 0 if the platform's main-equivalent has no argc. |
| char \*\* | **argv** | the argv parameter from the application's main() function, or NULL if the platform's main-equivalent has no argv. |
| [SDL_main_func](SDL_main_func.html) | **mainFunction** | your SDL app's C-style main(). NOT the function you're calling this from! Its name doesn't matter; it doesn't literally have to be `main`. |
| void \* | **reserved** | should be NULL (reserved for future use, will probably be platform-specific then). |

## Return Value

(int) Returns the return value from mainFunction: 0 on success,
otherwise failure; [SDL_GetError](SDL_GetError.html)() might have more
information on the failure.

## Remarks

You can use this if you want to use your own main() implementation
without using [SDL_main](SDL_main.html) (like when using
[SDL_MAIN_HANDLED](SDL_MAIN_HANDLED.html)). When using this, you do
*not* need [SDL_SetMainReady](SDL_SetMainReady.html)().

If `argv` is NULL, SDL will provide command line arguments, either by
querying the OS for them if possible, or supplying a filler array if
not.

## Thread Safety

Generally this is called once, near startup, from the process's initial
thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMain](CategoryMain.html)
