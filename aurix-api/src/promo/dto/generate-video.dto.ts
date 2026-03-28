import { IsInt, IsNumber, IsIn, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

export class GenerateVideoDto {
  @Type(() => Number)
  @IsInt()
  trackId: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  startTime: number;

  @Type(() => Number)
  @IsNumber()
  @Min(3)
  @Max(60)
  duration: number;

  @IsIn(['zoom', 'night', 'energy', 'sad', 'auto'])
  style: 'zoom' | 'night' | 'energy' | 'sad' | 'auto';
}
