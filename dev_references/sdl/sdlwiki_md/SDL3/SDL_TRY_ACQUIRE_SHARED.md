# SDL_TRY_ACQUIRE_SHARED

Wrapper around Clang thread safety analysis annotations.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_TRY_ACQUIRE_SHARED(x, y) \
  SDL_THREAD_ANNOTATION_ATTRIBUTE__(try_acquire_shared_capability(x, y))
```

</div>

## Remarks

Please see
<https://clang.llvm.org/docs/ThreadSafetyAnalysis.html#mutex-h>

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryMutex](CategoryMutex.html)
