# SDL_ELF_NOTE_DLOPEN_PRIORITY_RECOMMENDED

Use this macro with [SDL_ELF_NOTE_DLOPEN](SDL_ELF_NOTE_DLOPEN.html)() to
note that a dynamic shared library dependency is recommended.

## Header File

Defined in
[\<SDL3/SDL_dlopennote.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_dlopennote.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_ELF_NOTE_DLOPEN_PRIORITY_RECOMMENDED "recommended"
```

</div>

## Remarks

Important functionality needs the dependency, the binary will work but
in most cases the dependency should be provided.

## Version

This macro is available since SDL 3.4.0.

## See Also

- [SDL_ELF_NOTE_DLOPEN](SDL_ELF_NOTE_DLOPEN.html)
- [SDL_ELF_NOTE_DLOPEN_PRIORITY_SUGGESTED](SDL_ELF_NOTE_DLOPEN_PRIORITY_SUGGESTED.html)
- [SDL_ELF_NOTE_DLOPEN_PRIORITY_REQUIRED](SDL_ELF_NOTE_DLOPEN_PRIORITY_REQUIRED.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryDlopenNotes](CategoryDlopenNotes.html)
