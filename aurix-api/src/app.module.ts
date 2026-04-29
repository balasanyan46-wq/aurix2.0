import { Module } from '@nestjs/common';
import { ThrottlerModule } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DatabaseModule } from './database/database.module';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { ArtistsModule } from './artists/artists.module';
import { ReleasesModule } from './releases/releases.module';
import { TracksModule } from './tracks/tracks.module';
import { UploadModule } from './upload/upload.module';
import { ReleaseMetadataModule } from './release-metadata/release-metadata.module';
import { ProfilesModule } from './profiles/profiles.module';
import { MailModule } from './mail/mail.module';
import { TeamMembersModule } from './team-members/team-members.module';
import { SupportModule } from './support/support.module';
import { AdminLogsModule } from './admin-logs/admin-logs.module';
import { ReportsModule } from './reports/reports.module';
import { AiToolsModule } from './ai-tools/ai-tools.module';
import { LegalModule } from './legal/legal.module';
import { PromoModule } from './promo/promo.module';
import { ProgressModule } from './progress/progress.module';
import { ProductionModule } from './production/production.module';
import { CrmModule } from './crm/crm.module';
import { NavigatorModule } from './navigator/navigator.module';
import { AccountModule } from './account/account.module';
import { AaiModule } from './aai/aai.module';
import { AiModule } from './ai/ai.module';
import { UserEventsModule } from './user-events/user-events.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AutoActionsModule } from './auto-actions/auto-actions.module';
import { SessionsModule } from './sessions/sessions.module';
import { SettingsModule } from './settings/settings.module';
import { WsModule } from './ws/ws.module';
import { BillingModule } from './billing/billing.module';
import { GrowthModule } from './growth/growth.module';
import { SmartLinkModule } from './smart-link/smart-link.module';
import { StudioToolsModule } from './studio-tools/studio-tools.module';
import { BrainModule } from './brain/brain.module';
import { PaymentsModule } from './payments/payments.module';
import { BeatsModule } from './beats/beats.module';
import { ReferralModule } from './referral/referral.module';
import { TelegramModule } from './telegram/telegram.module';
import { CastingModule } from './casting/casting.module';
import { DonationsModule } from './donations/donations.module';
import { LeadScoringModule } from './lead-scoring/lead-scoring.module';
import { ActionCenterModule } from './action-center/action-center.module';
import { LeadsModule } from './leads/leads.module';
import { NextActionModule } from './next-action/next-action.module';
import { ConversionModule } from './conversion/conversion.module';
import { AiSalesModule } from './ai-sales/ai-sales.module';
import { SalesCronModule } from './sales-cron/sales-cron.module';
import { RevenueModule } from './revenue/revenue.module';
import { MessageTemplatesModule } from './message-templates/message-templates.module';
import { SalesAlertsModule } from './sales-alerts/sales-alerts.module';
import { PushModule } from './push/push.module';

@Module({
  imports: [
    ThrottlerModule.forRoot([{
      ttl: 60000,   // 1 minute window
      limit: 60,    // 60 requests per minute globally
    }]),
    ScheduleModule.forRoot(),
    DatabaseModule,
    MailModule,
    AuthModule,
    UsersModule,
    ArtistsModule,
    ReleasesModule,
    TracksModule,
    UploadModule,
    ReleaseMetadataModule,
    ProfilesModule,
    TeamMembersModule,
    SupportModule,
    AdminLogsModule,
    ReportsModule,
    AiToolsModule,
    LegalModule,
    PromoModule,
    ProgressModule,
    ProductionModule,
    CrmModule,
    NavigatorModule,
    AccountModule,
    AaiModule,
    AiModule,
    UserEventsModule,
    NotificationsModule,
    AutoActionsModule,
    SessionsModule,
    SettingsModule,
    WsModule,
    BillingModule,
    GrowthModule,
    SmartLinkModule,
    StudioToolsModule,
    BrainModule,
    // LeadsModule должен быть зарегистрирован ДО PaymentsModule, потому что
    // TBankService инжектит LeadsService (через @Optional) для markConverted
    // при успешном платеже. @Global делает его доступным везде, но явный
    // порядок повышает предсказуемость bootstrap.
    LeadsModule,
    // MessageTemplatesModule — глобальный, должен быть зарегистрирован
    // ДО NextActionModule (next-action.service injects его через @Optional).
    MessageTemplatesModule,
    // SalesAlertsModule — глобальный, инжектится в TBankService через @Optional
    // для notifyPaymentFailed. Должен быть до PaymentsModule.
    SalesAlertsModule,
    // PushModule — глобальный, для notifications.controller transport='push'.
    PushModule,
    LeadScoringModule,
    NextActionModule,
    PaymentsModule,
    CastingModule,
    BeatsModule,
    ReferralModule,
    TelegramModule,
    DonationsModule,
    ConversionModule,
    AiSalesModule,
    RevenueModule,        // SaaS-метрики: MRR, ARR, ARPU, LTV, churn, etc.
    ActionCenterModule,   // зависит от всех sales-модулей
    SalesCronModule,      // регулярные задачи: scoring, sweep, ai-sales
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
