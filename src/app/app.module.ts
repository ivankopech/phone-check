import { NgModule, APP_INITIALIZER } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { RouteReuseStrategy } from '@angular/router';

import { IonicModule, IonicRouteStrategy } from '@ionic/angular';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { DeviceSecurityService } from './services/device-security.service';

export function initializeSecurity(securityService: DeviceSecurityService) {
  return () => securityService.initialize();
}

@NgModule({
  declarations: [AppComponent],
  imports: [BrowserModule, IonicModule.forRoot(), AppRoutingModule],
  providers: [
    { provide: RouteReuseStrategy, useClass: IonicRouteStrategy },
    {
      provide: APP_INITIALIZER,
      useFactory: initializeSecurity,
      deps: [DeviceSecurityService],
      multi: true,
    },
  ],
  bootstrap: [AppComponent],
})
export class AppModule {}
