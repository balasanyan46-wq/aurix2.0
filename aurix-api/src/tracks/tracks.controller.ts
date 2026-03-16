import {
  Controller,
  Post,
  Get,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TracksService } from './tracks.service';
import { CreateTrackDto } from './dto/create-track.dto';

@UseGuards(JwtAuthGuard)
@Controller('tracks')
export class TracksController {
  constructor(private readonly tracksService: TracksService) {}

  @Post()
  async create(@Body() dto: CreateTrackDto) {
    if (!dto.release_id) {
      throw new HttpException(
        'release_id is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    const track = await this.tracksService.create(dto);
    return { success: true, track };
  }

  @Get('release/:id')
  async getByRelease(@Param('id') id: string) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const tracks = await this.tracksService.findByReleaseId(releaseId);
    return { success: true, tracks };
  }

  @Get()
  async search(@Query('isrc') isrc?: string) {
    if (isrc) {
      const tracks = await this.tracksService.findByIsrc(isrc);
      return tracks;
    }
    return [];
  }

  @Get(':id')
  async getOne(@Param('id') id: string) {
    const track = await this.tracksService.findById(+id);
    if (!track) throw new HttpException('track not found', HttpStatus.NOT_FOUND);
    return { success: true, track };
  }

  @Put(':id')
  async update(@Param('id') id: string, @Body() body: Record<string, any>) {
    const track = await this.tracksService.update(+id, body);
    if (!track) throw new HttpException('track not found', HttpStatus.NOT_FOUND);
    return { success: true, track };
  }

  @Delete(':id')
  async remove(@Param('id') id: string) {
    await this.tracksService.delete(+id);
    return { success: true };
  }
}
