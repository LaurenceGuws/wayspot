# SDL_RETURN_CAPABILITY

Wrapper around Clang thread safety analysis annotations.

## Header File

Defined in
[\<SDL3/SDL_mutex.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mutex.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_RETURN_CAPABILITY(x) \
  SDL_THREAD_ANNOTATION_ATTRIBUTE__(lock_returned(x))
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
