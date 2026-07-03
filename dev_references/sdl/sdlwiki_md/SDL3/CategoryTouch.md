# CategoryTouch

SDL offers touch input, on platforms that support it. It can manage
multiple touch devices and track multiple fingers on those devices.

Touches are mostly dealt with through the event system, in the
[SDL_EVENT_FINGER_DOWN](SDL_EVENT_FINGER_DOWN.html),
[SDL_EVENT_FINGER_MOTION](SDL_EVENT_FINGER_MOTION.html), and
[SDL_EVENT_FINGER_UP](SDL_EVENT_FINGER_UP.html) events, but there are
also functions to query for hardware details, etc.

The touch system, by default, will also send virtual mouse events; this
can be useful for making a some desktop apps work on a phone without
significant changes. For apps that care about mouse and touch input
separately, they should ignore mouse events that have a `which` field of
[SDL_TOUCH_MOUSEID](SDL_TOUCH_MOUSEID.html).

## Functions

- [SDL_GetTouchDeviceName](SDL_GetTouchDeviceName.html)
- [SDL_GetTouchDevices](SDL_GetTouchDevices.html)
- [SDL_GetTouchDeviceType](SDL_GetTouchDeviceType.html)
- [SDL_GetTouchFingers](SDL_GetTouchFingers.html)

## Datatypes

- [SDL_FingerID](SDL_FingerID.html)
- [SDL_TouchID](SDL_TouchID.html)

## Structs

- [SDL_Finger](SDL_Finger.html)

## Enums

- [SDL_TouchDeviceType](SDL_TouchDeviceType.html)

## Macros

- [SDL_MOUSE_TOUCHID](SDL_MOUSE_TOUCHID.html)
- [SDL_TOUCH_MOUSEID](SDL_TOUCH_MOUSEID.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
