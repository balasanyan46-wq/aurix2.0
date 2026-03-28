import { IsString, IsOptional, IsBoolean, IsInt, IsIn, MaxLength, Min, Max } from 'class-validator';

export class CreateReleaseDto {
  @IsString()
  @MaxLength(255)
  title: string;

  @IsOptional() @IsString() @MaxLength(255)
  artist?: string;

  @IsOptional() @IsIn(['single', 'ep', 'album'])
  release_type?: string;

  @IsOptional() @IsString() @MaxLength(1000)
  cover_url?: string;

  @IsOptional() @IsString() @MaxLength(1000)
  cover_path?: string;

  @IsOptional() @IsString() @MaxLength(20)
  release_date?: string;

  @IsOptional() @IsIn(['draft', 'submitted'])
  status?: string;

  @IsOptional() @IsString() @MaxLength(100)
  genre?: string;

  @IsOptional() @IsString() @MaxLength(10)
  language?: string;

  @IsOptional() @IsBoolean()
  explicit?: boolean;

  @IsOptional() @IsString() @MaxLength(20)
  upc?: string;

  @IsOptional() @IsString() @MaxLength(255)
  label?: string;

  @IsOptional() @IsInt() @Min(1900) @Max(2100)
  copyright_year?: number;
}
