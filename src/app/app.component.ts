import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { Platform, ToastController } from '@ionic/angular';
import { App } from '@capacitor/app';
import { Subscription } from 'rxjs';
import { DeviceSecurityService } from './services/device-security.service';

@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss'],
  standalone: false,
})
export class AppComponent implements OnInit, OnDestroy {
  isBlocked = false;
  failureReasons: string[] = [];
  private screenshotSub?: Subscription;

  constructor(
    private securityService: DeviceSecurityService,
    private platform: Platform,
    private cdr: ChangeDetectorRef,
    private toastController: ToastController
  ) {}

  ngOnInit(): void {
    this.updateBlockedState();

    // Re-check when app returns to foreground
    if (this.platform.is('capacitor')) {
      App.addListener('appStateChange', async (state) => {
        if (state.isActive) {
          await this.securityService.runSecurityChecks();
          this.updateBlockedState();
          this.cdr.detectChanges();
        }
      });
    }

    // Listen for screenshot detection events
    this.screenshotSub = this.securityService.onScreenshotDetected.subscribe(
      async () => {
        await this.showScreenshotWarning();
      }
    );
  }

  ngOnDestroy(): void {
    this.screenshotSub?.unsubscribe();
  }

  private async showScreenshotWarning(): Promise<void> {
    const toast = await this.toastController.create({
      message: 'Screenshots are not allowed for security reasons.',
      duration: 3000,
      position: 'top',
      color: 'danger',
      icon: 'shield-half-outline',
    });
    await toast.present();
  }

  private updateBlockedState(): void {
    this.isBlocked = this.securityService.isBlocked;
    this.failureReasons = this.securityService.failureReasons;
  }
}
