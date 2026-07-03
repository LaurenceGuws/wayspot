# SDL_HINT_GDK_TEXTINPUT_DEFAULT_TEXT

This variable sets the default text of the TextInput window on GDK
platforms.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_GDK_TEXTINPUT_DEFAULT_TEXT "SDL_GDK_TEXTINPUT_DEFAULT_TEXT"
```

</div>

## Remarks

This hint is available only if
[SDL_GDK_TEXTINPUT](SDL_GDK_TEXTINPUT.html) defined.

This hint should be set before calling
[SDL_StartTextInput](SDL_StartTextInput.html)()

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
