# SDL_ELF_NOTE_DLOPEN_PRIORITY_REQUIRED

Use this macro with [SDL_ELF_NOTE_DLOPEN](SDL_ELF_NOTE_DLOPEN.html)() to
note that a dynamic shared library dependency is required.

## Header File

Defined in
[\<SDL3/SDL_dlopennote.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_dlopennote.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_ELF_NOTE_DLOPEN_PRIORITY_REQUIRED    "required"
```

</div>

## Remarks

Core functionality needs the dependency, the binary will not work if it
cannot be found.

## Version

This macro is available since SDL 3.4.0.

## See Also

- [SDL_ELF_NOTE_DLOPEN](SDL_ELF_NOTE_DLOPEN.html)
- [SDL_ELF_NOTE_DLOPEN_PRIORITY_SUGGESTED](SDL_ELF_NOTE_DLOPEN_PRIORITY_SUGGESTED.html)
- [SDL_ELF_NOTE_DLOPEN_PRIORITY_RECOMMENDED](SDL_ELF_NOTE_DLOPEN_PRIORITY_RECOMMENDED.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryDlopenNotes](CategoryDlopenNotes.html)
