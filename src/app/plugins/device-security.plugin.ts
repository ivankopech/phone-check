import { registerPlugin, PluginListenerHandle } from '@capacitor/core';

// MARK: - Interfaces

export interface IntegrityCheckResult {
  isJailbroken: boolean;
  isEmulator: boolean;
  isDebugged: boolean;
  isDeveloperModeEnabled: boolean;
  isSecure: boolean;
  failureReasons: string[];
}

export interface AttestResult {
  success: boolean;
  error: string;
}

export interface SecurityCheckResult {
  secure: boolean;
  integrityCheck: {
    isJailbroken: boolean;
    isEmulator: boolean;
    isDebugged: boolean;
    isDeveloperModeEnabled: boolean;
  };
  attestation: {
    success: boolean;
    error: string;
  };
  failureReasons: string[];
}

export interface ScreenshotDetectedEvent {
  timestamp: string;
}

// MARK: - Plugin Interface

export interface DeviceSecurityPlugin {
  checkDeviceIntegrity(): Promise<IntegrityCheckResult>;
  attestDevice(): Promise<AttestResult>;
  isSecure(): Promise<SecurityCheckResult>;
  enableScreenshotDetection(): Promise<{ enabled: boolean }>;
  addListener(
    eventName: 'screenshotDetected',
    listenerFunc: (event: ScreenshotDetectedEvent) => void,
  ): Promise<PluginListenerHandle>;
  removeAllListeners(): Promise<void>;
}

// MARK: - Register Plugin

const DeviceSecurity = registerPlugin<DeviceSecurityPlugin>('DeviceSecurity');

export default DeviceSecurity;
