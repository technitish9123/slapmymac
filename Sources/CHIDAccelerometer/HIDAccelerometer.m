#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import <Security/Authorization.h>
#import <os/log.h>
#import <pthread.h>

#import "CHIDAccelerometer.h"

// ---------------------------------------------------------------------------
// MARK: - Constants
// ---------------------------------------------------------------------------

/// Vendor-defined usage page for the MacBook accelerometer (Sudden Motion Sensor).
static const uint32_t kAccelUsagePage = 0xFF00;

/// Vendor-defined usage within the above page that identifies the accelerometer.
static const uint32_t kAccelUsage = 3;

/// Expected HID report length from the accelerometer.
static const CFIndex kExpectedReportLength = 22;

/// Byte offsets within the 22-byte HID report for each axis (little-endian int32).
static const int kOffsetX = 6;
static const int kOffsetY = 10;
static const int kOffsetZ = 14;

/// Divisor to convert raw int32 values into g-force.
static const double kRawToDivisor = 65536.0;

// ---------------------------------------------------------------------------
// MARK: - Internal state
// ---------------------------------------------------------------------------

/// Per-instance state for an accelerometer reader.
typedef struct {
    IOHIDManagerRef _Nullable manager;
    CFRunLoopRef _Nullable runLoop;
    pthread_t thread;
    bool threadStarted;

    HIDAccelCallback callback;
    void * _Nullable context;

    /// Buffer for input reports.
    uint8_t reportBuffer[256];
} HIDAccelState;

static os_log_t _accelLog(void) {
    static os_log_t log = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        log = os_log_create("com.slapmymac.hidaccel", "HID");
    });
    return log;
}

// ---------------------------------------------------------------------------
// MARK: - HID matching dictionary
// ---------------------------------------------------------------------------

/// Build a matching dictionary for the accelerometer HID device.
static NSDictionary *_matchingDict(void) {
    return @{
        @(kIOHIDDeviceUsagePageKey): @(kAccelUsagePage),
        @(kIOHIDDeviceUsageKey):     @(kAccelUsage),
    };
}

// ---------------------------------------------------------------------------
// MARK: - Input report callback
// ---------------------------------------------------------------------------

/// Called by IOKit on the dedicated run-loop thread for every HID input report.
static void _inputReportCallback(
    void * _Nullable ctx,
    IOReturn result,
    void * _Nullable sender,
    IOHIDReportType type,
    uint32_t reportID,
    uint8_t *report,
    CFIndex reportLength
) {
    if (result != kIOReturnSuccess) {
        os_log_error(_accelLog(), "HID report callback error: 0x%x", result);
        return;
    }

    HIDAccelState *state = (HIDAccelState *)ctx;
    if (!state || !state->callback) return;

    if (reportLength < kExpectedReportLength) {
        os_log_debug(_accelLog(), "Short report (%ld bytes), skipping", (long)reportLength);
        return;
    }

    // Parse little-endian int32 values at the documented byte offsets.
    int32_t rawX, rawY, rawZ;
    memcpy(&rawX, report + kOffsetX, sizeof(int32_t));
    memcpy(&rawY, report + kOffsetY, sizeof(int32_t));
    memcpy(&rawZ, report + kOffsetZ, sizeof(int32_t));

    // Convert from little-endian to host byte order.
    rawX = OSSwapLittleToHostInt32(rawX);
    rawY = OSSwapLittleToHostInt32(rawY);
    rawZ = OSSwapLittleToHostInt32(rawZ);

    double x = (double)rawX / kRawToDivisor;
    double y = (double)rawY / kRawToDivisor;
    double z = (double)rawZ / kRawToDivisor;

    state->callback(state->context, x, y, z);
}

// ---------------------------------------------------------------------------
// MARK: - Dedicated run-loop thread
// ---------------------------------------------------------------------------

/// Entry point for the background pthread that hosts the HID manager's run loop.
static void *_runLoopThread(void *arg) {
    HIDAccelState *state = (HIDAccelState *)arg;

    // Retain the run loop reference so the main thread can stop it later.
    state->runLoop = CFRunLoopGetCurrent();
    CFRetain(state->runLoop);

    // Schedule the HID manager on this thread's run loop.
    IOHIDManagerScheduleWithRunLoop(
        state->manager,
        state->runLoop,
        kCFRunLoopDefaultMode
    );

    // Register for input reports from all matched devices.
    IOHIDManagerRegisterInputReportCallback(
        state->manager,
        _inputReportCallback,
        state
    );

    // Try opening without seize first (works on many M-series Macs without root).
    IOReturn openResult = IOHIDManagerOpen(state->manager, kIOHIDOptionsTypeNone);
    if (openResult != kIOReturnSuccess) {
        os_log_info(_accelLog(), "Normal open failed (0x%x), trying with seize...", openResult);
        openResult = IOHIDManagerOpen(state->manager, kIOHIDOptionsTypeSeizeDevice);
    }
    if (openResult != kIOReturnSuccess) {
        os_log_error(_accelLog(), "Failed to open HID manager: 0x%x. Try running with sudo.", openResult);
        CFRelease(state->runLoop);
        state->runLoop = NULL;
        return NULL;
    }

    os_log_info(_accelLog(), "Accelerometer HID run loop starting");

    // Run until explicitly stopped via CFRunLoopStop().
    CFRunLoopRun();

    os_log_info(_accelLog(), "Accelerometer HID run loop exited");
    return NULL;
}

// ---------------------------------------------------------------------------
// MARK: - Public API
// ---------------------------------------------------------------------------

/// Attempt to acquire an authorization right that elevates HID access
/// without running the entire process as root. This prompts the user once
/// for an admin password via the standard macOS dialog.
static bool _acquireHIDAuthorization(void) {
    AuthorizationRef authRef = NULL;
    OSStatus status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment,
                                          kAuthorizationFlagDefaults, &authRef);
    if (status != errAuthorizationSuccess) {
        os_log_error(_accelLog(), "AuthorizationCreate failed: %d", (int)status);
        return false;
    }

    AuthorizationItem right = { "com.slapmymac.hid-access", 0, NULL, 0 };
    AuthorizationRights rights = { 1, &right };
    AuthorizationFlags flags = kAuthorizationFlagInteractionAllowed |
                               kAuthorizationFlagExtendRights |
                               kAuthorizationFlagPreAuthorize;

    status = AuthorizationCopyRights(authRef, &rights, kAuthorizationEmptyEnvironment,
                                     flags, NULL);
    AuthorizationFree(authRef, kAuthorizationFlagDefaults);

    if (status == errAuthorizationSuccess) {
        os_log_info(_accelLog(), "HID authorization acquired");
        return true;
    }
    os_log_error(_accelLog(), "HID authorization denied: %d", (int)status);
    return false;
}

void * _Nullable HIDAccelCreate(HIDAccelCallback _Nonnull callback, void * _Nullable context) {
    HIDAccelState *state = calloc(1, sizeof(HIDAccelState));
    if (!state) {
        os_log_error(_accelLog(), "Failed to allocate HIDAccelState");
        return NULL;
    }

    state->callback = callback;
    state->context = context;

    // Create the HID manager.
    state->manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!state->manager) {
        os_log_error(_accelLog(), "Failed to create IOHIDManager");
        free(state);
        return NULL;
    }

    // Set the matching dictionary to filter for the accelerometer device.
    IOHIDManagerSetDeviceMatching(
        state->manager,
        (__bridge CFDictionaryRef)_matchingDict()
    );

    // Spawn a dedicated thread so the HID run loop doesn't block the main thread.
    int err = pthread_create(&state->thread, NULL, _runLoopThread, state);
    if (err != 0) {
        os_log_error(_accelLog(), "pthread_create failed: %d", err);
        CFRelease(state->manager);
        free(state);
        return NULL;
    }
    state->threadStarted = true;

    os_log_info(_accelLog(), "HIDAccelCreate succeeded, reader started");
    return state;
}

void HIDAccelDestroy(void * _Nonnull handle) {
    HIDAccelState *state = (HIDAccelState *)handle;
    if (!state) return;

    os_log_info(_accelLog(), "HIDAccelDestroy: tearing down");

    // Stop the run loop, which will cause the thread to exit.
    if (state->runLoop) {
        CFRunLoopStop(state->runLoop);
    }

    // Wait for the thread to finish.
    if (state->threadStarted) {
        pthread_join(state->thread, NULL);
    }

    // Close and release the HID manager.
    if (state->manager) {
        IOHIDManagerClose(state->manager, kIOHIDOptionsTypeNone);
        if (state->runLoop) {
            IOHIDManagerUnscheduleFromRunLoop(
                state->manager,
                state->runLoop,
                kCFRunLoopDefaultMode
            );
        }
        CFRelease(state->manager);
    }

    if (state->runLoop) {
        CFRelease(state->runLoop);
    }

    free(state);
    os_log_info(_accelLog(), "HIDAccelDestroy: cleanup complete");
}

bool HIDAccelIsAvailable(void) {
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!manager) return false;

    IOHIDManagerSetDeviceMatching(manager, (__bridge CFDictionaryRef)_matchingDict());

    // Opening in seize mode is not needed; we just want to enumerate.
    IOReturn result = IOHIDManagerOpen(manager, kIOHIDOptionsTypeNone);
    if (result != kIOReturnSuccess) {
        CFRelease(manager);
        return false;
    }

    CFSetRef devices = IOHIDManagerCopyDevices(manager);
    bool available = (devices != NULL && CFSetGetCount(devices) > 0);

    if (devices) CFRelease(devices);
    IOHIDManagerClose(manager, kIOHIDOptionsTypeNone);
    CFRelease(manager);

    os_log_info(_accelLog(), "HIDAccelIsAvailable: %{public}s", available ? "YES" : "NO");
    return available;
}
