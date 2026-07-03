# CategoryJoystick

SDL joystick support.

This is the lower-level joystick handling. If you want the simpler
option, where what each button does is well-defined, you should use the
gamepad API instead.

The term "instance_id" is the current instantiation of a joystick device
in the system. If the joystick is removed and then re-inserted then it
will get a new instance_id. instance_id's are monotonically increasing
identifiers of a joystick plugged in.

The term "player_index" is the number assigned to a player on a specific
controller. For XInput controllers this returns the XInput user index.
Many joysticks will not be able to supply this information.

[SDL_GUID](SDL_GUID.html) is used as a stable 128-bit identifier for a
joystick device that does not change over time. It identifies class of
the device (a X360 wired controller for example). This identifier is
platform dependent.

In order to use these functions, [SDL_Init](SDL_Init.html)() must have
been called with the [SDL_INIT_JOYSTICK](SDL_INIT_JOYSTICK.html) flag.
This causes SDL to scan the system for joysticks, and load appropriate
drivers.

If you would like to receive joystick updates while the application is
in the background, you should set the following hint before calling
[SDL_Init](SDL_Init.html)():
[SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS](SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS.html)

SDL can provide virtual joysticks as well: the app defines an imaginary
controller with
[SDL_AttachVirtualJoystick](SDL_AttachVirtualJoystick.html)(), and then
can provide inputs for it via
[SDL_SetJoystickVirtualAxis](SDL_SetJoystickVirtualAxis.html)(),
[SDL_SetJoystickVirtualButton](SDL_SetJoystickVirtualButton.html)(),
etc. As this data is supplied, it will look like a normal joystick to
SDL, just not backed by a hardware driver. This has been used to make
unusual devices, like VR headset controllers, look like normal
joysticks, or provide recording/playback of game inputs, etc.

## Functions

- [SDL_AttachVirtualJoystick](SDL_AttachVirtualJoystick.html)
- [SDL_CloseJoystick](SDL_CloseJoystick.html)
- [SDL_DetachVirtualJoystick](SDL_DetachVirtualJoystick.html)
- [SDL_GetJoystickAxis](SDL_GetJoystickAxis.html)
- [SDL_GetJoystickAxisInitialState](SDL_GetJoystickAxisInitialState.html)
- [SDL_GetJoystickBall](SDL_GetJoystickBall.html)
- [SDL_GetJoystickButton](SDL_GetJoystickButton.html)
- [SDL_GetJoystickConnectionState](SDL_GetJoystickConnectionState.html)
- [SDL_GetJoystickFirmwareVersion](SDL_GetJoystickFirmwareVersion.html)
- [SDL_GetJoystickFromID](SDL_GetJoystickFromID.html)
- [SDL_GetJoystickFromPlayerIndex](SDL_GetJoystickFromPlayerIndex.html)
- [SDL_GetJoystickGUID](SDL_GetJoystickGUID.html)
- [SDL_GetJoystickGUIDForID](SDL_GetJoystickGUIDForID.html)
- [SDL_GetJoystickGUIDInfo](SDL_GetJoystickGUIDInfo.html)
- [SDL_GetJoystickHat](SDL_GetJoystickHat.html)
- [SDL_GetJoystickID](SDL_GetJoystickID.html)
- [SDL_GetJoystickName](SDL_GetJoystickName.html)
- [SDL_GetJoystickNameForID](SDL_GetJoystickNameForID.html)
- [SDL_GetJoystickPath](SDL_GetJoystickPath.html)
- [SDL_GetJoystickPathForID](SDL_GetJoystickPathForID.html)
- [SDL_GetJoystickPlayerIndex](SDL_GetJoystickPlayerIndex.html)
- [SDL_GetJoystickPlayerIndexForID](SDL_GetJoystickPlayerIndexForID.html)
- [SDL_GetJoystickPowerInfo](SDL_GetJoystickPowerInfo.html)
- [SDL_GetJoystickProduct](SDL_GetJoystickProduct.html)
- [SDL_GetJoystickProductForID](SDL_GetJoystickProductForID.html)
- [SDL_GetJoystickProductVersion](SDL_GetJoystickProductVersion.html)
- [SDL_GetJoystickProductVersionForID](SDL_GetJoystickProductVersionForID.html)
- [SDL_GetJoystickProperties](SDL_GetJoystickProperties.html)
- [SDL_GetJoysticks](SDL_GetJoysticks.html)
- [SDL_GetJoystickSerial](SDL_GetJoystickSerial.html)
- [SDL_GetJoystickType](SDL_GetJoystickType.html)
- [SDL_GetJoystickTypeForID](SDL_GetJoystickTypeForID.html)
- [SDL_GetJoystickVendor](SDL_GetJoystickVendor.html)
- [SDL_GetJoystickVendorForID](SDL_GetJoystickVendorForID.html)
- [SDL_GetNumJoystickAxes](SDL_GetNumJoystickAxes.html)
- [SDL_GetNumJoystickBalls](SDL_GetNumJoystickBalls.html)
- [SDL_GetNumJoystickButtons](SDL_GetNumJoystickButtons.html)
- [SDL_GetNumJoystickHats](SDL_GetNumJoystickHats.html)
- [SDL_HasJoystick](SDL_HasJoystick.html)
- [SDL_IsJoystickVirtual](SDL_IsJoystickVirtual.html)
- [SDL_JoystickConnected](SDL_JoystickConnected.html)
- [SDL_JoystickEventsEnabled](SDL_JoystickEventsEnabled.html)
- [SDL_LockJoysticks](SDL_LockJoysticks.html)
- [SDL_OpenJoystick](SDL_OpenJoystick.html)
- [SDL_RumbleJoystick](SDL_RumbleJoystick.html)
- [SDL_RumbleJoystickTriggers](SDL_RumbleJoystickTriggers.html)
- [SDL_SendJoystickEffect](SDL_SendJoystickEffect.html)
- [SDL_SendJoystickVirtualSensorData](SDL_SendJoystickVirtualSensorData.html)
- [SDL_SetJoystickEventsEnabled](SDL_SetJoystickEventsEnabled.html)
- [SDL_SetJoystickLED](SDL_SetJoystickLED.html)
- [SDL_SetJoystickPlayerIndex](SDL_SetJoystickPlayerIndex.html)
- [SDL_SetJoystickVirtualAxis](SDL_SetJoystickVirtualAxis.html)
- [SDL_SetJoystickVirtualBall](SDL_SetJoystickVirtualBall.html)
- [SDL_SetJoystickVirtualButton](SDL_SetJoystickVirtualButton.html)
- [SDL_SetJoystickVirtualHat](SDL_SetJoystickVirtualHat.html)
- [SDL_SetJoystickVirtualTouchpad](SDL_SetJoystickVirtualTouchpad.html)
- [SDL_TryLockJoysticks](SDL_TryLockJoysticks.html)
- [SDL_UnlockJoysticks](SDL_UnlockJoysticks.html)
- [SDL_UpdateJoysticks](SDL_UpdateJoysticks.html)

## Datatypes

- [SDL_Joystick](SDL_Joystick.html)
- [SDL_JoystickID](SDL_JoystickID.html)

## Structs

- [SDL_VirtualJoystickDesc](SDL_VirtualJoystickDesc.html)
- [SDL_VirtualJoystickSensorDesc](SDL_VirtualJoystickSensorDesc.html)
- [SDL_VirtualJoystickTouchpadDesc](SDL_VirtualJoystickTouchpadDesc.html)

## Enums

- [SDL_JoystickConnectionState](SDL_JoystickConnectionState.html)
- [SDL_JoystickType](SDL_JoystickType.html)

## Macros

- [SDL_JOYSTICK_AXIS_MAX](SDL_JOYSTICK_AXIS_MAX.html)
- [SDL_JOYSTICK_AXIS_MIN](SDL_JOYSTICK_AXIS_MIN.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
