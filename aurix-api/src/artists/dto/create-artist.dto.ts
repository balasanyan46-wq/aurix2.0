import { IsString, IsOptional, MaxLength } from 'class-validator';

export class CreateArtistDto {
  @IsString()
  @MaxLength(255)
  artist_name: string;

  @IsOptional() @IsString() @MaxLength(2000)
  bio?: string;

  @IsOptional() @IsString() @MaxLength(1000)
  avatar_url?: string;
}
