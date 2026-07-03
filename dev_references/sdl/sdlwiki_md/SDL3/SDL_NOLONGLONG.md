# SDL_NOLONGLONG

Don't let SDL use "long long" C types.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_NOLONGLONG 1
```

</div>

## Remarks

SDL will define this if it believes the compiler doesn't understand the
"long long" syntax for C datatypes. This can happen on older compilers.

If *your* compiler doesn't support "long long" but SDL doesn't know it,
it is safe to define this yourself to build against the SDL headers.

If this is defined, it will remove access to some C runtime support
functions, like [SDL_ulltoa](SDL_ulltoa.html) and
[SDL_strtoll](SDL_strtoll.html) that refer to this datatype explicitly.
The rest of SDL will still be available.

SDL's own source code cannot be built with a compiler that has this
defined, for various technical reasons.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
