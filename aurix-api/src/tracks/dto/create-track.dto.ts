export class CreateTrackDto {
  release_id: number;
  title?: string;
  audio_url?: string;
  audio_path?: string;
  duration?: number;
  isrc?: string;
  track_number?: number;
  version?: string;
  explicit?: boolean;
}
