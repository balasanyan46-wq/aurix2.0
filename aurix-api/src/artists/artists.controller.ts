import {
  Controller,
  Post,
  Get,
  Body,
  Req,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ArtistsService } from './artists.service';
import { CreateArtistDto } from './dto/create-artist.dto';

@UseGuards(JwtAuthGuard)
@Controller('artists')
export class ArtistsController {
  constructor(private readonly artistsService: ArtistsService) {}

  @Post()
  async create(@Req() req: any, @Body() dto: CreateArtistDto) {
    if (!dto.artist_name) {
      throw new HttpException('artist_name is required', HttpStatus.BAD_REQUEST);
    }

    const existing = await this.artistsService.findByUserId(req.user.id);
    if (existing) {
      throw new HttpException('artist profile already exists', HttpStatus.CONFLICT);
    }

    const artist = await this.artistsService.create(req.user.id, dto);
    return { success: true, artist };
  }

  @Get('me')
  async getMe(@Req() req: any) {
    const artist = await this.artistsService.findByUserId(req.user.id);
    if (!artist) {
      throw new HttpException('artist profile not found', HttpStatus.NOT_FOUND);
    }
    return { success: true, artist };
  }
}
