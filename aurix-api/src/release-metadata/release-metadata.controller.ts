import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Req,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ReleaseMetadataService } from './release-metadata.service';
import { ReleasesService } from '../releases/releases.service';
import { ArtistsService } from '../artists/artists.service';
import { UpsertMetadataDto } from './dto/upsert-metadata.dto';

@UseGuards(JwtAuthGuard)
@Controller('releases')
export class ReleaseMetadataController {
  constructor(
    private readonly metadataService: ReleaseMetadataService,
    private readonly releasesService: ReleasesService,
    private readonly artistsService: ArtistsService,
  ) {}

  @Post(':id/metadata')
  async upsert(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpsertMetadataDto,
  ) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const release = await this.releasesService.findById(releaseId);
    if (!release) {
      throw new HttpException('release not found', HttpStatus.NOT_FOUND);
    }

    const artist = await this.artistsService.findByUserId(req.user.id);
    if (!artist || release.artist_id !== artist.id) {
      throw new HttpException('not your release', HttpStatus.FORBIDDEN);
    }

    const metadata = await this.metadataService.upsert(releaseId, dto);
    return { success: true, metadata };
  }

  @Get(':id/metadata')
  async get(@Req() req: any, @Param('id') id: string) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const release = await this.releasesService.findById(releaseId);
    if (!release) {
      throw new HttpException('release not found', HttpStatus.NOT_FOUND);
    }

    const artist = await this.artistsService.findByUserId(req.user.id);
    if (!artist || release.artist_id !== artist.id) {
      throw new HttpException('not your release', HttpStatus.FORBIDDEN);
    }

    const metadata = await this.metadataService.findByReleaseId(releaseId);
    return { success: true, metadata };
  }
}
