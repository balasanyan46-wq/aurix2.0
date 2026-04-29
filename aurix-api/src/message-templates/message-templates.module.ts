import { Module, Global } from '@nestjs/common';
import { MessageTemplatesService } from './message-templates.service';
import { MessageTemplatesController } from './message-templates.controller';

// @Global — используется next-action.service для pickVariant.
// Глобальная регистрация позволяет инжектить без явных imports.
@Global()
@Module({
  controllers: [MessageTemplatesController],
  providers: [MessageTemplatesService],
  exports: [MessageTemplatesService],
})
export class MessageTemplatesModule {}
