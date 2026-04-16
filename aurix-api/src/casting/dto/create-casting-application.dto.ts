import { IsString, IsOptional, MaxLength, IsIn } from 'class-validator';

export class CreateCastingPurchaseDto {
  @IsString()
  @MaxLength(255)
  name: string;

  @IsString()
  @MaxLength(30)
  phone: string;

  @IsString()
  @MaxLength(100)
  city: string;

  @IsString()
  @IsIn(['base', 'pro', 'vip'])
  plan: string;
}
