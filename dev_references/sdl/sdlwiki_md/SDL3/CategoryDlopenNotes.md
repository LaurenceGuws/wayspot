# CategoryDlopenNotes

This header allows you to annotate your code so external tools know
about dynamic shared library dependencies.

If you determine that your toolchain doesn't support dlopen notes, you
can disable this feature by defining
[`SDL_DISABLE_DLOPEN_NOTES`](SDL_DISABLE_DLOPEN_NOTES.html). You can use
this CMake snippet to check for support:

<div id="cb1" class="sourceCode">

``` sourceCode
include(CheckCSourceCompiles)
find_package(SDL3 REQUIRED CONFIG COMPONENTS Headers)
list(APPEND CMAKE_REQUIRED_LIBRARIES SDL3::Headers)
check_c_source_compiles([==[
  #include <SDL3/SDL_dlopennote.h>
  SDL_ELF_NOTE_DLOPEN("sdl-video",
    "Support for video through SDL",
    SDL_ELF_NOTE_DLOPEN_PRIORITY_SUGGESTED,
    "libSDL-1.2.so.0", "libSDL-2.0.so.0", "libSDL3.so.0"
  )
  int main(int argc, char *argv[]) {
    return argc + argv[0][1];
  }
]==] COMPILER_SUPPORTS_SDL_ELF_NOTE_DLOPEN)
if(NOT COMPILER_SUPPORTS_SDL_ELF_NOTE_DLOPEN)
  add_compile_definitions(-DSDL_DISABLE_DLOPEN_NOTE)
endif()
```

</div>

## Functions

- (none.)

## Datatypes

- (none.)

## Structs

- (none.)

## Enums

- (none.)

## Macros

- [SDL_ELF_NOTE_DLOPEN](SDL_ELF_NOTE_DLOPEN.html)
- [SDL_ELF_NOTE_DLOPEN_PRIORITY_RECOMMENDED](SDL_ELF_NOTE_DLOPEN_PRIORITY_RECOMMENDED.html)
- [SDL_ELF_NOTE_DLOPEN_PRIORITY_REQUIRED](SDL_ELF_NOTE_DLOPEN_PRIORITY_REQUIRED.html)
- [SDL_ELF_NOTE_DLOPEN_PRIORITY_SUGGESTED](SDL_ELF_NOTE_DLOPEN_PRIORITY_SUGGESTED.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
