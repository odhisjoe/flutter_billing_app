import { MiddlewareConsumer, Module, NestModule, Global } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import { databaseConfig } from './config/database.config';
import { AuthModule } from './auth/auth.module';
import { PairingModule } from './pairing/pairing.module';
import { SyncModule } from './sync/sync.module';
import { PaymentsModule } from './payments/payments.module';
import { BackupModule } from './backup/backup.module';
import { LogRedactionMiddleware } from './common/log-redaction.middleware';
import { EncryptionService } from './common/encryption.service';
import { AppController } from './app.controller';

@Global()
@Module({
  imports: [
    TypeOrmModule.forRoot(databaseConfig),
    ScheduleModule.forRoot(),
    AuthModule,
    PairingModule,
    SyncModule,
    PaymentsModule,
    BackupModule,
  ],
  controllers: [AppController],
  providers: [EncryptionService],
  exports: [EncryptionService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LogRedactionMiddleware).forRoutes('*');
  }
}
