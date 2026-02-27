import { Injectable } from '@angular/core';
import { Platform } from '@ionic/angular';
import { App } from '@capacitor/app';
import { Subject, Observable } from 'rxjs';
import DeviceSecurity, { SecurityCheckResult, ScreenshotDetectedEvent } from '../plugins/device-security.plugin';

@Injectable({
  providedIn: 'root',
})
export class DeviceSecurityService {
  private lastCheckResult: SecurityCheckResult | null = null;
  private _isBlocked = false;
  private screenshotDetected$ = new Subject<ScreenshotDetectedEvent>();

  constructor(private platform: Platform) {}

  /**
   * Initialize security checks. Called by APP_INITIALIZER.
   */
  async initialize(): Promise<void> {
    if (!this.platform.is('capacitor')) {
      // Running in browser during development - skip checks
      console.warn('[DeviceSecurity] Not running on native platform, skipping checks.');
      return;
    }

    await this.runSecurityChecks();
    this.setupForegroundListener();
    await this.setupScreenshotDetection();
  }

  /**
   * Setup screenshot detection listener.
   */
  private async setupScreenshotDetection(): Promise<void> {
    try {
      await DeviceSecurity.enableScreenshotDetection();
      await DeviceSecurity.addListener('screenshotDetected', (event) => {
        console.warn('[DeviceSecurity] Screenshot detected at:', event.timestamp);
        this.screenshotDetected$.next(event);
      });
    } catch (error) {
      console.error('[DeviceSecurity] Failed to setup screenshot detection:', error);
    }
  }

  /**
   * Observable that emits when a screenshot is detected.
   */
  get onScreenshotDetected(): Observable<ScreenshotDetectedEvent> {
    return this.screenshotDetected$.asObservable();
  }

  /**
   * Run all security checks (manual + App Attest).
   */
  async runSecurityChecks(): Promise<SecurityCheckResult> {
    try {
      const result = await DeviceSecurity.isSecure();
      this.lastCheckResult = result;

      if (!result.secure) {
        this._isBlocked = true;
        console.error('[DeviceSecurity] Device blocked:', result.failureReasons);
      } else {
        console.log('[DeviceSecurity] Device passed all security checks.');
      }

      return result;
    } catch (error) {
      // If the plugin call itself fails, treat as insecure
      console.error('[DeviceSecurity] Plugin call failed:', error);
      this._isBlocked = true;

      const fallbackResult: SecurityCheckResult = {
        secure: false,
        integrityCheck: {
          isJailbroken: false,
          isEmulator: true,
          isDebugged: false,
          isDeveloperModeEnabled: false,
        },
        attestation: {
          success: false,
          error: 'Security plugin unavailable',
        },
        failureReasons: ['Security plugin unavailable - possible emulator or tampered environment'],
      };

      this.lastCheckResult = fallbackResult;
      return fallbackResult;
    }
  }

  /**
   * Re-check security every time the app returns to foreground.
   */
  private setupForegroundListener(): void {
    App.addListener('appStateChange', async (state) => {
      if (state.isActive) {
        await this.runSecurityChecks();
      }
    });
  }

  /**
   * Whether the app is currently blocked.
   */
  get isBlocked(): boolean {
    return this._isBlocked;
  }

  /**
   * Get the last security check result.
   */
  get lastResult(): SecurityCheckResult | null {
    return this.lastCheckResult;
  }

  /**
   * Get failure reasons from the last check.
   */
  get failureReasons(): string[] {
    return this.lastCheckResult?.failureReasons ?? [];
  }
}
