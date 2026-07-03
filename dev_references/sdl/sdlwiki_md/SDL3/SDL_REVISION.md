# SDL_REVISION

This macro is a string describing the source at a particular point in
development.

## Header File

Defined in
[\<SDL3/SDL_revision.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_revision.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_REVISION "Some arbitrary string decided at SDL build time"
```

</div>

## Remarks

This string is often generated from revision control's state at build
time.

This string can be quite complex and does not follow any standard. For
example, it might be something like
"SDL-prerelease-3.1.1-47-gf687e0732". It might also be user-defined at
build time, so it's best to treat it as a clue in debugging forensics
and not something the app will parse in any way.

[SDL_revision](SDL_revision.html).h must be included in your program
explicitly if you want access to the [SDL_REVISION](SDL_REVISION.html)
constant.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryVersion](CategoryVersion.html)
