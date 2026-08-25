import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

class DeviceHardwareProfile {
  final double? totalRamGB;
  final double? availableRamGB;
  final String cpuArchitecture;
  final int cpuCores;
  final bool? hasGpuAcceleration;
  final double? availableStorageGB;
  final String? thermalState;
  final int? batteryLevel;

  const DeviceHardwareProfile({
    required this.totalRamGB,
    required this.availableRamGB,
    required this.cpuArchitecture,
    required this.cpuCores,
    required this.hasGpuAcceleration,
    required this.availableStorageGB,
    required this.thermalState,
    this.batteryLevel,
  });
}

abstract class DeviceHardwareProbe {
  Future<Map<String, dynamic>> read();
}

class MethodChannelDeviceProbe implements DeviceHardwareProbe {
  static const _channel = MethodChannel('pocketllm_lite/device');

  @override
  Future<Map<String, dynamic>> read() async {
    final result =
        await _channel.invokeMapMethod<String, dynamic>('getProfile');
    return result ?? const {};
  }
}

class DeviceSpecService {
  final DeviceHardwareProbe _probe;
  DeviceHardwareProfile? _cachedProfile;

  DeviceSpecService({DeviceHardwareProbe? probe})
      : _probe = probe ?? MethodChannelDeviceProbe();

  Future<DeviceHardwareProfile> getHardwareProfile(
      {bool refresh = false}) async {
    if (!refresh && _cachedProfile != null) return _cachedProfile!;
    Map<String, dynamic> values = const {};
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        values = await _probe.read();
      } on PlatformException {
        values = const {};
      } on MissingPluginException {
        values = const {};
      }
    }
    double? gib(dynamic bytes) => bytes is num && bytes >= 0
        ? bytes.toDouble() / (1024 * 1024 * 1024)
        : null;
    final profile = DeviceHardwareProfile(
      totalRamGB: gib(values['totalRamBytes']),
      availableRamGB: gib(values['availableRamBytes']),
      cpuArchitecture:
          values['cpuArchitecture'] as String? ?? Abi.current().toString(),
      cpuCores: values['cpuCores'] as int? ?? Platform.numberOfProcessors,
      hasGpuAcceleration: values['hasGpuAcceleration'] as bool?,
      availableStorageGB: gib(values['availableStorageBytes']),
      thermalState: values['thermalState'] as String?,
      batteryLevel: values['batteryLevel'] as int?,
    );
    _cachedProfile = profile;
    return profile;
  }
}
