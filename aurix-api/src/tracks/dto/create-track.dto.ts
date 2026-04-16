import { IsString, IsOptional, IsBoolean, IsInt, IsNumber, MaxLength, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateTrackDto {
  @Type(() => Number)
  @IsInt()
  release_id: number;

  @IsOptional() @IsString() @MaxLength(255)
  title?: string;

  @IsOptional() @IsString() @MaxLength(1000)
  audio_url?: string;

  @IsOptional() @IsString() @MaxLength(1000)
  audio_path?: string;

  @IsOptional() @IsNumber() @Min(0)
  duration?: number;

  @IsOptional() @IsString() @MaxLength(20)
  isrc?: string;

  @IsOptional() @IsInt() @Min(1)
  track_number?: number;

  @IsOptional() @IsString() @MaxLength(50)
  version?: string;

  @IsOptional() @IsBoolean()
  explicit?: boolean;
}
