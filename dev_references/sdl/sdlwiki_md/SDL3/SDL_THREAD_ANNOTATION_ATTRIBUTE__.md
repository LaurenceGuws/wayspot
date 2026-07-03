# SDL_THREAD_ANNOTATION_ATTRIBUTE\_\_

Enable thread safety attributes, only with clang.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_THREAD_ANNOTATION_ATTRIBUTE__(x)   __attribute__((x))
```

</div>

## Remarks

The attributes can be safely erased when compiling with other compilers.

To enable analysis, set these environment variables before running
cmake:

<div id="cb2" class="sourceCode">

``` sourceCode
export CC=clang
export CFLAGS="-DSDL_THREAD_SAFETY_ANALYSIS -Wthread-safety"
```

</div>

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryMutex](CategoryMutex.html)
