import { IsString, IsOptional, MaxLength } from 'class-validator';

export class RejectReleaseDto {
  @IsOptional() @IsString() @MaxLength(2000)
  reason?: string;
}
