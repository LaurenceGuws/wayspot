# SDL_HAS_BUILTIN

Check if the compiler supports a given builtin functionality.

## Header File

Defined in
[\<SDL3/SDL_begin_code.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_begin_code.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HAS_BUILTIN(x) __has_builtin(x)
```

</div>

## Remarks

This allows preprocessor checks for things that otherwise might fail to
compile.

Supported by virtually all clang versions and more-recent GCCs. Use this
instead of checking the clang version if possible.

On compilers without has_builtin support, this is defined to 0 (always
false).

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryBeginCode](CategoryBeginCode.html)
