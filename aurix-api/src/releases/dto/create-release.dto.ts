export class CreateReleaseDto {
  title: string;
  artist?: string;
  release_type?: string;
  cover_url?: string;
  cover_path?: string;
  release_date?: string;
  status?: string;
  genre?: string;
  language?: string;
  explicit?: boolean;
  upc?: string;
  label?: string;
  copyright_year?: number;
}
