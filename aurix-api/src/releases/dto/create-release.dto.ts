import { IsString, IsOptional, IsBoolean, IsInt, IsIn, IsNumber, IsArray, MaxLength, Min, Max } from 'class-validator';

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

  // ── Extended fields (v2) ──

  @IsOptional() @IsString() @MaxLength(5000)
  description?: string;

  @IsOptional() @IsString()
  lyrics?: string;

  @IsOptional() @IsString()
  copyright_holders?: string;

  @IsOptional()
  platform_links?: Record<string, string>;

  @IsOptional()
  services?: Array<{ id: string; name: string; price: number; enabled: boolean }>;

  @IsOptional() @IsNumber()
  total_price?: number;

  @IsOptional() @IsInt() @Min(20) @Max(300)
  bpm?: number;

  @IsOptional() @IsString() @MaxLength(100)
  mood?: string;

  @IsOptional() @IsString() @MaxLength(1000)
  target_audience?: string;

  @IsOptional() @IsString() @MaxLength(2000)
  reference_tracks?: string;

  @IsOptional() @IsBoolean()
  tiktok_clip?: boolean;

  @IsOptional()
  ai_generated?: Record<string, boolean>;

  @IsOptional() @IsInt() @Min(0) @Max(6)
  wizard_step?: number;
}
