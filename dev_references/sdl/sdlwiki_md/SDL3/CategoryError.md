# CategoryError

Simple error message routines for SDL.

Most apps will interface with these APIs in exactly one function: when
almost any SDL function call reports failure, you can get a
human-readable string of the problem from
[SDL_GetError](SDL_GetError.html)().

These strings are maintained per-thread, and apps are welcome to set
their own errors, which is popular when building libraries on top of SDL
for other apps to consume. These strings are set by calling
[SDL_SetError](SDL_SetError.html)().

A common usage pattern is to have a function that returns true for
success and false for failure, and do this when something fails:

<div id="cb1" class="sourceCode">

``` sourceCode
if (something_went_wrong) {
   return SDL_SetError("The thing broke in this specific way: %d", errcode);
}
```

</div>

It's also common to just return `false` in this case if the failing
thing is known to call [SDL_SetError](SDL_SetError.html)(), so errors
simply propagate through.

## Functions

- [SDL_ClearError](SDL_ClearError.html)
- [SDL_GetError](SDL_GetError.html)
- [SDL_OutOfMemory](SDL_OutOfMemory.html)
- [SDL_SetError](SDL_SetError.html)
- [SDL_SetErrorV](SDL_SetErrorV.html)

## Datatypes

- (none.)

## Structs

- (none.)

## Enums

- (none.)

## Macros

- [SDL_InvalidParamError](SDL_InvalidParamError.html)
- [SDL_Unsupported](SDL_Unsupported.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
