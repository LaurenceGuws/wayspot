# SDL_HINT_KEYCODE_OPTIONS

A variable that controls keycode representation in keyboard events.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_KEYCODE_OPTIONS "SDL_KEYCODE_OPTIONS"
```

</div>

## Remarks

This variable is a comma separated set of options for translating
keycodes in events:

- "none": Keycode options are cleared, this overrides other options.
- "hide_numpad": The numpad keysyms will be translated into their
  non-numpad versions based on the current NumLock state. For example,
  [SDLK_KP_4](SDLK_KP_4.html) would become [SDLK_4](SDLK_4.html) if
  [SDL_KMOD_NUM](SDL_KMOD_NUM.html) is set in the event modifiers, and
  [SDLK_LEFT](SDLK_LEFT.html) if it is unset.
- "french_numbers": The number row on French keyboards is inverted, so
  pressing the 1 key would yield the keycode [SDLK_1](SDLK_1.html), or
  '1', instead of [SDLK_AMPERSAND](SDLK_AMPERSAND.html), or '&'
- "latin_letters": For keyboards using non-Latin letters, such as
  Russian or Thai, the letter keys generate keycodes as though it had an
  English QWERTY layout. e.g. pressing the key associated with
  [SDL_SCANCODE_A](SDL_SCANCODE_A.html) on a Russian keyboard would
  yield 'a' instead of a Cyrillic letter.

The default value for this hint is "french_numbers,latin_letters"

Some platforms like Emscripten only provide modified keycodes and the
options are not used.

These options do not affect the return value of
[SDL_GetKeyFromScancode](SDL_GetKeyFromScancode.html)() or
[SDL_GetScancodeFromKey](SDL_GetScancodeFromKey.html)(), they just apply
to the keycode included in key events.

This hint can be set anytime.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
