#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import "GyroTweak.h"

static CMMotionManager* _motionManager = nil;
static dispatch_queue_t _motionQueue = nil;

// Автозапуск при загрузке dylib (можно убрать, если не нужен)
__attribute__((constructor))
static void GyroTweak_Constructor(void) {
    // GyroTweak_Init();
}

// Автоочистка при выгрузке
__attribute__((destructor))
static void GyroTweak_Destructor(void) {
    GyroTweak_Shutdown();
}

int GyroTweak_Init(void) {
    if (_motionManager != nil) {
        return 0; // Уже инициализирован
    }

    _motionManager = [[CMMotionManager alloc] init];
    if (!_motionManager) {
        return -1;
    }

    _motionQueue = dispatch_queue_create("com.gyrotweak.motion", DISPATCH_QUEUE_SERIAL);
    if (!_motionQueue) {
        [_motionManager release];
        _motionManager = nil;
        return -1;
    }

    // Частота обновления: 60 Гц (стандарт для игр)
    _motionManager.gyroUpdateInterval = 1.0 / 60.0;
    _motionManager.accelerometerUpdateInterval = 1.0 / 60.0;
    _motionManager.deviceMotionUpdateInterval = 1.0 / 60.0;

    // Запуск гироскопа
    if ([_motionManager isGyroAvailable]) {
        [_motionManager startGyroUpdatesToQueue:_motionQueue withHandler:^(CMGyroData* gyroData, NSError* err) {
            // Данные читаются через GyroTweak_GetRotationRate
        }];
    }

    // Запуск акселерометра
    if ([_motionManager isAccelerometerAvailable]) {
        [_motionManager startAccelerometerUpdatesToQueue:_motionQueue withHandler:^(CMAccelerometerData* accelData, NSError* err) {
            // Данные читаются через GyroTweak_GetAcceleration
        }];
    }

    // DeviceMotion = гироскоп + акселерометр + магнетометр (fusion)
    // Даёт готовый quaternion ориентации
    if ([_motionManager isDeviceMotionAvailable]) {
        [_motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical
                                                           toQueue:_motionQueue
                                                      withHandler:^(CMDeviceMotion* motion, NSError* err) {
            // Данные читаются через GyroTweak_GetAttitudeQuaternion
        }];
    }

    return 0;
}

void GyroTweak_Shutdown(void) {
    if (_motionManager) {
        [_motionManager stopGyroUpdates];
        [_motionManager stopAccelerometerUpdates];
        [_motionManager stopDeviceMotionUpdates];
        [_motionManager release];
        _motionManager = nil;
    }
    if (_motionQueue) {
        dispatch_release(_motionQueue);
        _motionQueue = nil;
    }
}

int GyroTweak_GetRotationRate(float* outX, float* outY, float* outZ) {
    if (!_motionManager || !_motionManager.gyroData) {
        return -1;
    }
    CMGyroData* data = _motionManager.gyroData;
    if (outX) *outX = data.rotationRate.x;
    if (outY) *outY = data.rotationRate.y;
    if (outZ) *outZ = data.rotationRate.z;
    return 0;
}

int GyroTweak_GetAcceleration(float* outX, float* outY, float* outZ) {
    if (!_motionManager || !_motionManager.accelerometerData) {
        return -1;
    }
    CMAccelerometerData* data = _motionManager.accelerometerData;
    if (outX) *outX = data.acceleration.x;
    if (outY) *outY = data.acceleration.y;
    if (outZ) *outZ = data.acceleration.z;
    return 0;
}

int GyroTweak_GetAttitudeQuaternion(float* outX, float* outY, float* outZ, float* outW) {
    if (!_motionManager || !_motionManager.deviceMotion) {
        return -1;
    }
    CMAttitude* attitude = _motionManager.deviceMotion.attitude;
    if (outX) *outX = attitude.quaternion.x;
    if (outY) *outY = attitude.quaternion.y;
    if (outZ) *outZ = attitude.quaternion.z;
    if (outW) *outW = attitude.quaternion.w;
    return 0;
}

int GyroTweak_IsAvailable(void) {
    if (!_motionManager) return 0;
    return [_motionManager isGyroAvailable] || [_motionManager isDeviceMotionAvailable];
}
