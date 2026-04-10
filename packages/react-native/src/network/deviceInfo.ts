import { Platform } from 'react-native';
import { BUILD_VERSION } from '../config/constants';

interface DeviceInfoPayload {
  device_id: string;
  platform: string;
  os: string;
  os_version: string;
  app_version: string;
}

/**
 * Build the URL-encoded JSON string for the `Device-Info` request header.
 *
 * ```json
 * {
 *   "device_id":   "<stored stable uuid>",
 *   "platform":    "react-native",
 *   "os":          "ios" | "android",
 *   "os_version":  "<Platform.Version>",
 *   "app_version": "<from expo-constants>"
 * }
 * ```
 */
export function buildDeviceInfoHeader(deviceId: string): string {
  let appVersion = '0.0.0';
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const Constants = require('expo-constants').default;
    appVersion = Constants.expoConfig?.version ?? Constants.manifest?.version ?? '0.0.0';
  } catch {
    // expo-constants not available
  }

  const payload: DeviceInfoPayload = {
    device_id:   deviceId,
    platform:    'react-native',
    os:          Platform.OS,
    os_version:  String(Platform.Version),
    app_version: appVersion,
  };

  return encodeURIComponent(JSON.stringify(payload));
}

export { BUILD_VERSION };
