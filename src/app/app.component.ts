import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { Platform } from '@ionic/angular';
import { App } from '@capacitor/app';
import { DeviceSecurityService } from './services/device-security.service';

@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss'],
  standalone: false,
})
export class AppComponent implements OnInit {
  isBlocked = false;
  failureReasons: string[] = [];

  constructor(
    private securityService: DeviceSecurityService,
    private platform: Platform,
    private cdr: ChangeDetectorRef
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
  }

  private updateBlockedState(): void {
    this.isBlocked = this.securityService.isBlocked;
    this.failureReasons = this.securityService.failureReasons;
  }
}
