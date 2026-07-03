# SDL_enabled_assert

The macro used when an assertion is enabled.

## Header File

Defined in
[\<SDL3/SDL_assert.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_assert.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_enabled_assert(condition) \
    do { \
        while ( !(condition) ) { \
            static struct SDL_AssertData sdl_assert_data = { false, 0, #condition, NULL, 0, NULL, NULL }; \
            const SDL_AssertState sdl_assert_state = SDL_ReportAssertion(&sdl_assert_data, SDL_FUNCTION, SDL_ASSERT_FILE, SDL_LINE); \
            if (sdl_assert_state == SDL_ASSERTION_RETRY) { \
                continue; /* go again. */ \
            } else if (sdl_assert_state == SDL_ASSERTION_BREAK) { \
                SDL_AssertBreakpoint(); \
            } \
            break; /* not retrying. */ \
        } \
    } while (SDL_NULL_WHILE_LOOP_CONDITION)
```

</div>

## Macro Parameters

|               |                          |
|---------------|--------------------------|
| **condition** | the condition to assert. |

## Remarks

This isn't for direct use by apps, but this is the code that is inserted
when an [SDL_assert](SDL_assert.html) is enabled.

The `do {} while(0)` avoids dangling else problems:

<div id="cb2" class="sourceCode">

``` sourceCode
if (x) SDL_assert(y); else blah();
```

</div>

... without the do/while, the "else" could attach to this macro's "if".
We try to handle just the minimum we need here in a macro...the loop,
the static vars, and break points. The heavy lifting is handled in
[SDL_ReportAssertion](SDL_ReportAssertion.html)().

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAssert](CategoryAssert.html)
