# CategoryEvents

Event queue management.

It's extremely common--often required--that an app deal with SDL's event
queue. Almost all useful information about interactions with the real
world flow through here: the user interacting with the computer and app,
hardware coming and going, the system changing in some way, etc.

An app generally takes a moment, perhaps at the start of a new frame, to
examine any events that have occurred since the last time and process or
ignore them. This is generally done by calling
[SDL_PollEvent](SDL_PollEvent.html)() in a loop until it returns false
(or, if using the main callbacks, events are provided one at a time in
calls to [SDL_AppEvent](SDL_AppEvent.html)() before the next call to
[SDL_AppIterate](SDL_AppIterate.html)(); in this scenario, the app does
not call [SDL_PollEvent](SDL_PollEvent.html)() at all).

There is other forms of control, too:
[SDL_PeepEvents](SDL_PeepEvents.html)() has more functionality at the
cost of more complexity, and [SDL_WaitEvent](SDL_WaitEvent.html)() can
block the process until something interesting happens, which might be
beneficial for certain types of programs on low-power hardware. One may
also call [SDL_AddEventWatch](SDL_AddEventWatch.html)() to set a
callback when new events arrive.

The app is free to generate their own events, too:
[SDL_PushEvent](SDL_PushEvent.html) allows the app to put events onto
the queue for later retrieval;
[SDL_RegisterEvents](SDL_RegisterEvents.html) can guarantee that these
events have a type that isn't in use by other parts of the system.

## Functions

- [SDL_AddEventWatch](SDL_AddEventWatch.html)
- [SDL_EventEnabled](SDL_EventEnabled.html)
- [SDL_FilterEvents](SDL_FilterEvents.html)
- [SDL_FlushEvent](SDL_FlushEvent.html)
- [SDL_FlushEvents](SDL_FlushEvents.html)
- [SDL_GetEventDescription](SDL_GetEventDescription.html)
- [SDL_GetEventFilter](SDL_GetEventFilter.html)
- [SDL_GetWindowFromEvent](SDL_GetWindowFromEvent.html)
- [SDL_HasEvent](SDL_HasEvent.html)
- [SDL_HasEvents](SDL_HasEvents.html)
- [SDL_PeepEvents](SDL_PeepEvents.html)
- [SDL_PollEvent](SDL_PollEvent.html)
- [SDL_PumpEvents](SDL_PumpEvents.html)
- [SDL_PushEvent](SDL_PushEvent.html)
- [SDL_RegisterEvents](SDL_RegisterEvents.html)
- [SDL_RemoveEventWatch](SDL_RemoveEventWatch.html)
- [SDL_SetEventEnabled](SDL_SetEventEnabled.html)
- [SDL_SetEventFilter](SDL_SetEventFilter.html)
- [SDL_WaitEvent](SDL_WaitEvent.html)
- [SDL_WaitEventTimeout](SDL_WaitEventTimeout.html)

## Datatypes

- [SDL_EventFilter](SDL_EventFilter.html)

## Structs

- [SDL_AudioDeviceEvent](SDL_AudioDeviceEvent.html)
- [SDL_CameraDeviceEvent](SDL_CameraDeviceEvent.html)
- [SDL_ClipboardEvent](SDL_ClipboardEvent.html)
- [SDL_CommonEvent](SDL_CommonEvent.html)
- [SDL_DisplayEvent](SDL_DisplayEvent.html)
- [SDL_DropEvent](SDL_DropEvent.html)
- [SDL_Event](SDL_Event.html)
- [SDL_GamepadAxisEvent](SDL_GamepadAxisEvent.html)
- [SDL_GamepadButtonEvent](SDL_GamepadButtonEvent.html)
- [SDL_GamepadDeviceEvent](SDL_GamepadDeviceEvent.html)
- [SDL_GamepadSensorEvent](SDL_GamepadSensorEvent.html)
- [SDL_GamepadTouchpadEvent](SDL_GamepadTouchpadEvent.html)
- [SDL_JoyAxisEvent](SDL_JoyAxisEvent.html)
- [SDL_JoyBallEvent](SDL_JoyBallEvent.html)
- [SDL_JoyBatteryEvent](SDL_JoyBatteryEvent.html)
- [SDL_JoyButtonEvent](SDL_JoyButtonEvent.html)
- [SDL_JoyDeviceEvent](SDL_JoyDeviceEvent.html)
- [SDL_JoyHatEvent](SDL_JoyHatEvent.html)
- [SDL_KeyboardDeviceEvent](SDL_KeyboardDeviceEvent.html)
- [SDL_KeyboardEvent](SDL_KeyboardEvent.html)
- [SDL_MouseButtonEvent](SDL_MouseButtonEvent.html)
- [SDL_MouseDeviceEvent](SDL_MouseDeviceEvent.html)
- [SDL_MouseMotionEvent](SDL_MouseMotionEvent.html)
- [SDL_MouseWheelEvent](SDL_MouseWheelEvent.html)
- [SDL_PenAxisEvent](SDL_PenAxisEvent.html)
- [SDL_PenButtonEvent](SDL_PenButtonEvent.html)
- [SDL_PenMotionEvent](SDL_PenMotionEvent.html)
- [SDL_PenProximityEvent](SDL_PenProximityEvent.html)
- [SDL_PenTouchEvent](SDL_PenTouchEvent.html)
- [SDL_PinchFingerEvent](SDL_PinchFingerEvent.html)
- [SDL_QuitEvent](SDL_QuitEvent.html)
- [SDL_RenderEvent](SDL_RenderEvent.html)
- [SDL_SensorEvent](SDL_SensorEvent.html)
- [SDL_TextEditingCandidatesEvent](SDL_TextEditingCandidatesEvent.html)
- [SDL_TextEditingEvent](SDL_TextEditingEvent.html)
- [SDL_TextInputEvent](SDL_TextInputEvent.html)
- [SDL_TouchFingerEvent](SDL_TouchFingerEvent.html)
- [SDL_UserEvent](SDL_UserEvent.html)
- [SDL_WindowEvent](SDL_WindowEvent.html)

## Enums

- [SDL_EventAction](SDL_EventAction.html)
- [SDL_EventType](SDL_EventType.html)

## Macros

- (none.)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
