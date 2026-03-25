#ifndef CHIDAccelerometer_h
#define CHIDAccelerometer_h

#include <stdbool.h>

/// Callback invoked on every accelerometer sample.
/// @param context  Opaque pointer passed through from HIDAccelCreate.
/// @param x  Acceleration along the X axis in g-force.
/// @param y  Acceleration along the Y axis in g-force.
/// @param z  Acceleration along the Z axis in g-force.
typedef void (*HIDAccelCallback)(void * _Nullable context, double x, double y, double z);

/// Create an accelerometer reader. Returns an opaque handle, or NULL on failure.
/// The callback will be invoked on a dedicated background thread.
/// @param callback  Function pointer called for every HID report.
/// @param context   Opaque pointer forwarded to every callback invocation.
void * _Nullable HIDAccelCreate(HIDAccelCallback _Nonnull callback, void * _Nullable context);

/// Destroy a previously created accelerometer reader and release all resources.
/// @param handle  Opaque handle returned by HIDAccelCreate. Must not be NULL.
void HIDAccelDestroy(void * _Nonnull handle);

/// Quick check whether a compatible accelerometer HID device is present.
/// Does not start streaming; safe to call at any time.
bool HIDAccelIsAvailable(void);

#endif /* CHIDAccelerometer_h */
