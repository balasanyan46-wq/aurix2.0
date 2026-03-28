import { IsString, IsOptional, IsBoolean, IsIn, MaxLength } from 'class-validator';

export class UpsertMetadataDto {
  @IsOptional() @IsString() @MaxLength(100)
  genre?: string;

  @IsOptional() @IsString() @MaxLength(10)
  language?: string;

  @IsOptional() @IsBoolean()
  explicit?: boolean;

  @IsOptional() @IsString() @MaxLength(255)
  copyright?: string;

  @IsOptional() @IsString() @MaxLength(255)
  publisher?: string;

  @IsOptional() @IsString() @MaxLength(255)
  label?: string;

  @IsOptional() @IsIn(['single', 'ep', 'album'])
  release_type?: string;

  @IsOptional() @IsString() @MaxLength(20)
  upc?: string;
}
