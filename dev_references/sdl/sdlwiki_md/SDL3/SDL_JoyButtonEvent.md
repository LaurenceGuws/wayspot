# SDL_JoyButtonEvent

Joystick button event structure (event.jbutton.\*)

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_JoyButtonEvent
{
    SDL_EventType type; /**< SDL_EVENT_JOYSTICK_BUTTON_DOWN or SDL_EVENT_JOYSTICK_BUTTON_UP */
    Uint32 reserved;
    Uint64 timestamp;   /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
    Uint8 button;       /**< The joystick button index */
    bool down;      /**< true if the button is pressed */
    Uint8 padding1;
    Uint8 padding2;
} SDL_JoyButtonEvent;
```

</div>

## Version

This struct is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryEvents](CategoryEvents.html)
