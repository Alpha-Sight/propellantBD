import { Module } from '@nestjs/common';
import { AuthModule } from './module/v1/auth/auth.module';
import { UserModule } from './module/v1/user/user.module';
import { RepositoryModule } from './module/v1/repository/repository.module';
import { OtpModule } from './module/v1/otp/otp.module';
import { MailModule } from './module/v1/mail /mail.module';
import { SettingModule } from './module/v1/setting/setting.module';
import { DatabaseModule } from './module/v1/database/database.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';

@Module({
  imports: [
    DatabaseModule,
    AuthModule,
    UserModule,
    RepositoryModule,
    MailModule,
    OtpModule,
    SettingModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
