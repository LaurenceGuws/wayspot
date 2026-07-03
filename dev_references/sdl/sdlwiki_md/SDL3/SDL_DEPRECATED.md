# SDL_DEPRECATED

A macro to tag a symbol as deprecated.

## Header File

Defined in
[\<SDL3/SDL_begin_code.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_begin_code.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_DEPRECATED __attribute__((deprecated))
```

</div>

## Remarks

A function is marked deprecated by adding this macro to its declaration:

<div id="cb2" class="sourceCode">

``` sourceCode
extern SDL_DEPRECATED int ThisFunctionWasABadIdea(void);
```

</div>

Compilers with deprecation support can give a warning when a deprecated
function is used. This symbol may be used in SDL's headers, but apps are
welcome to use it for their own interfaces as well.

SDL, on occasion, might deprecate a function for various reasons.
However, SDL never removes symbols before major versions, so deprecated
interfaces in SDL3 will remain available until SDL4, where it would be
expected an app would have to take steps to migrate anyhow.

On compilers without a deprecation mechanism, this is defined to
nothing, and using a deprecated function will not generate a warning.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryBeginCode](CategoryBeginCode.html)
