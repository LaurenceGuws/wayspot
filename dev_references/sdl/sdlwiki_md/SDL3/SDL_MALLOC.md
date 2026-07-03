# SDL_MALLOC

A macro to tag a function as an allocator.

## Header File

Defined in
[\<SDL3/SDL_begin_code.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_begin_code.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_MALLOC __declspec(allocator) __desclspec(restrict)
```

</div>

## Remarks

This is a hint to the compiler that a function is an allocator, like
malloc(), with certain rules. A description of how GCC treats this hint
is here:

<https://gcc.gnu.org/onlinedocs/gcc/Common-Function-Attributes.html#index-malloc-function-attribute>

On compilers without allocator tag support, this is defined to nothing.

Most apps don't need to, and should not, use this directly.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryBeginCode](CategoryBeginCode.html)
