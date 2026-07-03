# CategoryHaptic

The SDL haptic subsystem manages haptic (force feedback) devices.

The basic usage is as follows:

- Initialize the subsystem ([SDL_INIT_HAPTIC](SDL_INIT_HAPTIC.html)).
- Open a haptic device.
- [SDL_OpenHaptic](SDL_OpenHaptic.html)() to open from index.
- [SDL_OpenHapticFromJoystick](SDL_OpenHapticFromJoystick.html)() to
  open from an existing joystick.
- Create an effect ([SDL_HapticEffect](SDL_HapticEffect.html)).
- Upload the effect with
  [SDL_CreateHapticEffect](SDL_CreateHapticEffect.html)().
- Run the effect with [SDL_RunHapticEffect](SDL_RunHapticEffect.html)().
- (optional) Free the effect with
  [SDL_DestroyHapticEffect](SDL_DestroyHapticEffect.html)().
- Close the haptic device with
  [SDL_CloseHaptic](SDL_CloseHaptic.html)().

Simple rumble example:

<div id="cb1" class="sourceCode">

``` sourceCode
   SDL_Haptic *haptic = NULL;

   // Open the device
   SDL_HapticID *haptics = SDL_GetHaptics(NULL);
   if (haptics) {
       haptic = SDL_OpenHaptic(haptics[0]);
       SDL_free(haptics);
   }
   if (haptic == NULL)
      return;

   // Initialize simple rumble
   if (!SDL_InitHapticRumble(haptic))
      return;

   // Play effect at 50% strength for 2 seconds
   if (!SDL_PlayHapticRumble(haptic, 0.5, 2000))
      return;
   SDL_Delay(2000);

   // Clean up
   SDL_CloseHaptic(haptic);
```

</div>

Complete example:

<div id="cb2" class="sourceCode">

``` sourceCode
bool test_haptic(SDL_Joystick *joystick)
{
   SDL_Haptic *haptic;
   SDL_HapticEffect effect;
   SDL_HapticEffectID effect_id;

   // Open the device
   haptic = SDL_OpenHapticFromJoystick(joystick);
   if (haptic == NULL) return false; // Most likely joystick isn't haptic

   // See if it can do sine waves
   if ((SDL_GetHapticFeatures(haptic) & SDL_HAPTIC_SINE)==0) {
      SDL_CloseHaptic(haptic); // No sine effect
      return false;
   }

   // Create the effect
   SDL_memset(&effect, 0, sizeof(SDL_HapticEffect)); // 0 is safe default
   effect.type = SDL_HAPTIC_SINE;
   effect.periodic.direction.type = SDL_HAPTIC_POLAR; // Polar coordinates
   effect.periodic.direction.dir[0] = 18000; // Force comes from south
   effect.periodic.period = 1000; // 1000 ms
   effect.periodic.magnitude = 20000; // 20000/32767 strength
   effect.periodic.length = 5000; // 5 seconds long
   effect.periodic.attack_length = 1000; // Takes 1 second to get max strength
   effect.periodic.fade_length = 1000; // Takes 1 second to fade away

   // Upload the effect
   effect_id = SDL_CreateHapticEffect(haptic, &effect);

   // Test the effect
   SDL_RunHapticEffect(haptic, effect_id, 1);
   SDL_Delay(5000); // Wait for the effect to finish

   // We destroy the effect, although closing the device also does this
   SDL_DestroyHapticEffect(haptic, effect_id);

   // Close the device
   SDL_CloseHaptic(haptic);

   return true; // Success
}
```

</div>

Note that the SDL haptic subsystem is not thread-safe.

## Functions

- [SDL_CloseHaptic](SDL_CloseHaptic.html)
- [SDL_CreateHapticEffect](SDL_CreateHapticEffect.html)
- [SDL_DestroyHapticEffect](SDL_DestroyHapticEffect.html)
- [SDL_GetHapticEffectStatus](SDL_GetHapticEffectStatus.html)
- [SDL_GetHapticFeatures](SDL_GetHapticFeatures.html)
- [SDL_GetHapticFromID](SDL_GetHapticFromID.html)
- [SDL_GetHapticID](SDL_GetHapticID.html)
- [SDL_GetHapticName](SDL_GetHapticName.html)
- [SDL_GetHapticNameForID](SDL_GetHapticNameForID.html)
- [SDL_GetHaptics](SDL_GetHaptics.html)
- [SDL_GetMaxHapticEffects](SDL_GetMaxHapticEffects.html)
- [SDL_GetMaxHapticEffectsPlaying](SDL_GetMaxHapticEffectsPlaying.html)
- [SDL_GetNumHapticAxes](SDL_GetNumHapticAxes.html)
- [SDL_HapticEffectSupported](SDL_HapticEffectSupported.html)
- [SDL_HapticRumbleSupported](SDL_HapticRumbleSupported.html)
- [SDL_InitHapticRumble](SDL_InitHapticRumble.html)
- [SDL_IsJoystickHaptic](SDL_IsJoystickHaptic.html)
- [SDL_IsMouseHaptic](SDL_IsMouseHaptic.html)
- [SDL_OpenHaptic](SDL_OpenHaptic.html)
- [SDL_OpenHapticFromJoystick](SDL_OpenHapticFromJoystick.html)
- [SDL_OpenHapticFromMouse](SDL_OpenHapticFromMouse.html)
- [SDL_PauseHaptic](SDL_PauseHaptic.html)
- [SDL_PlayHapticRumble](SDL_PlayHapticRumble.html)
- [SDL_ResumeHaptic](SDL_ResumeHaptic.html)
- [SDL_RunHapticEffect](SDL_RunHapticEffect.html)
- [SDL_SetHapticAutocenter](SDL_SetHapticAutocenter.html)
- [SDL_SetHapticGain](SDL_SetHapticGain.html)
- [SDL_StopHapticEffect](SDL_StopHapticEffect.html)
- [SDL_StopHapticEffects](SDL_StopHapticEffects.html)
- [SDL_StopHapticRumble](SDL_StopHapticRumble.html)
- [SDL_UpdateHapticEffect](SDL_UpdateHapticEffect.html)

## Datatypes

- [SDL_Haptic](SDL_Haptic.html)
- [SDL_HapticDirectionType](SDL_HapticDirectionType.html)
- [SDL_HapticEffectID](SDL_HapticEffectID.html)
- [SDL_HapticEffectType](SDL_HapticEffectType.html)
- [SDL_HapticID](SDL_HapticID.html)

## Structs

- [SDL_HapticCondition](SDL_HapticCondition.html)
- [SDL_HapticConstant](SDL_HapticConstant.html)
- [SDL_HapticCustom](SDL_HapticCustom.html)
- [SDL_HapticDirection](SDL_HapticDirection.html)
- [SDL_HapticEffect](SDL_HapticEffect.html)
- [SDL_HapticLeftRight](SDL_HapticLeftRight.html)
- [SDL_HapticPeriodic](SDL_HapticPeriodic.html)
- [SDL_HapticRamp](SDL_HapticRamp.html)

## Enums

- (none.)

## Macros

- [SDL_HAPTIC_AUTOCENTER](SDL_HAPTIC_AUTOCENTER.html)
- [SDL_HAPTIC_CARTESIAN](SDL_HAPTIC_CARTESIAN.html)
- [SDL_HAPTIC_CONSTANT](SDL_HAPTIC_CONSTANT.html)
- [SDL_HAPTIC_CUSTOM](SDL_HAPTIC_CUSTOM.html)
- [SDL_HAPTIC_DAMPER](SDL_HAPTIC_DAMPER.html)
- [SDL_HAPTIC_FRICTION](SDL_HAPTIC_FRICTION.html)
- [SDL_HAPTIC_GAIN](SDL_HAPTIC_GAIN.html)
- [SDL_HAPTIC_INERTIA](SDL_HAPTIC_INERTIA.html)
- [SDL_HAPTIC_INFINITY](SDL_HAPTIC_INFINITY.html)
- [SDL_HAPTIC_LEFTRIGHT](SDL_HAPTIC_LEFTRIGHT.html)
- [SDL_HAPTIC_PAUSE](SDL_HAPTIC_PAUSE.html)
- [SDL_HAPTIC_POLAR](SDL_HAPTIC_POLAR.html)
- [SDL_HAPTIC_RAMP](SDL_HAPTIC_RAMP.html)
- [SDL_HAPTIC_RESERVED1](SDL_HAPTIC_RESERVED1.html)
- [SDL_HAPTIC_RESERVED2](SDL_HAPTIC_RESERVED2.html)
- [SDL_HAPTIC_RESERVED3](SDL_HAPTIC_RESERVED3.html)
- [SDL_HAPTIC_SAWTOOTHDOWN](SDL_HAPTIC_SAWTOOTHDOWN.html)
- [SDL_HAPTIC_SAWTOOTHUP](SDL_HAPTIC_SAWTOOTHUP.html)
- [SDL_HAPTIC_SINE](SDL_HAPTIC_SINE.html)
- [SDL_HAPTIC_SPHERICAL](SDL_HAPTIC_SPHERICAL.html)
- [SDL_HAPTIC_SPRING](SDL_HAPTIC_SPRING.html)
- [SDL_HAPTIC_SQUARE](SDL_HAPTIC_SQUARE.html)
- [SDL_HAPTIC_STATUS](SDL_HAPTIC_STATUS.html)
- [SDL_HAPTIC_STEERING_AXIS](SDL_HAPTIC_STEERING_AXIS.html)
- [SDL_HAPTIC_TRIANGLE](SDL_HAPTIC_TRIANGLE.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
