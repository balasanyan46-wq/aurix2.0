import { Injectable, Logger } from '@nestjs/common';
import { execFile } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { randomUUID } from 'crypto';

const exec = promisify(execFile);
const mkdir = promisify(fs.mkdir);
const unlink = promisify(fs.unlink);
const fsStat = promisify(fs.stat);

export type VideoStyle = 'zoom' | 'night' | 'energy' | 'sad';
export type VideoStyleInput = VideoStyle | 'auto';

// Keywords for auto-style detection
const STYLE_KEYWORDS: Record<VideoStyle, string[]> = {
  sad:    ['sad', 'love', 'pain', 'грусть', 'боль', 'слёзы', 'tears', 'broken', 'alone', 'lonely', 'miss', 'cry', 'heart', 'ballad', 'slow', 'rain'],
  night:  ['night', 'city', 'dark', 'ночь', 'город', 'тьма', 'urban', 'midnight', 'shadow', 'neon', 'chill', 'lo-fi', 'lofi', 'ambient', 'deep'],
  energy: ['club', 'energy', 'trap', 'bass', 'hype', 'fire', 'rage', 'hard', 'drill', 'phonk', 'бит', 'клуб', 'жёстк', 'bang', 'drop', 'bounce', 'party'],
  zoom:   [], // fallback
};

@Injectable()
export class FfmpegService {
  private readonly logger = new Logger(FfmpegService.name);
  private readonly tmpDir = path.join(os.tmpdir(), 'aurix-promo');

  async ensureTmpDir(): Promise<void> {
    await mkdir(this.tmpDir, { recursive: true });
  }

  tmpFile(ext: string): string {
    return path.join(this.tmpDir, `${randomUUID()}${ext}`);
  }

  // ── Auto-detect style from track metadata ────────────────
  detectStyle(title?: string, releaseTitle?: string, genre?: string): VideoStyle {
    const text = [title, releaseTitle, genre].filter(Boolean).join(' ').toLowerCase();
    if (!text) return 'zoom';

    for (const style of ['sad', 'night', 'energy'] as VideoStyle[]) {
      if (STYLE_KEYWORDS[style].some(kw => text.includes(kw))) {
        return style;
      }
    }
    return 'zoom';
  }

  // ── Cut audio segment ─────────────────────────────────────
  async cutAudio(
    inputPath: string,
    outputPath: string,
    startTime: number,
    duration: number,
  ): Promise<void> {
    const args = [
      '-y',
      '-i', inputPath,
      '-ss', String(startTime),
      '-t', String(duration),
      '-c:a', 'aac',
      '-b:a', '192k',
      '-ar', '44100',
      outputPath,
    ];
    this.logger.log(`[cutAudio] ffmpeg ${args.join(' ')}`);
    const { stderr } = await exec('ffmpeg', args, { timeout: 60_000 });
    if (stderr) this.logger.debug(`[cutAudio] ${stderr.slice(0, 500)}`);
  }

  // ── Generate animated waveform video from audio ───────────
  async generateWaveformVideo(
    audioPath: string,
    outputPath: string,
    duration: number,
    width: number,
    height: number,
    color: string,
  ): Promise<void> {
    const args = [
      '-y',
      '-i', audioPath,
      '-filter_complex',
      `[0:a]showwaves=s=${width}x${height}:mode=cline:rate=30:colors=${color}:scale=sqrt,` +
      `format=rgba[wv]`,
      '-map', '[wv]',
      '-t', String(duration),
      '-c:v', 'png',
      '-an',
      outputPath,
    ];
    this.logger.log('[generateWaveformVideo] creating animated waveform');
    const { stderr } = await exec('ffmpeg', args, { timeout: 120_000 });
    if (stderr) this.logger.debug(`[waveformVideo] ${stderr.slice(0, 300)}`);
  }

  // ── Generate styled video ─────────────────────────────────
  async generateVideo(opts: {
    coverPath: string;
    audioPath: string;
    outputPath: string;
    duration: number;
    style: VideoStyle;
  }): Promise<void> {
    const { coverPath, audioPath, outputPath, duration, style } = opts;

    // Step 1: generate animated waveform video
    const waveformPath = this.tmpFile('.mov');
    const waveColor = this.waveformColor(style);
    await this.generateWaveformVideo(audioPath, waveformPath, duration, 1080, 100, waveColor);
    this.logger.log('[generateVideo] waveform video ready');

    // Step 2: build main video with all layers
    const filter = this.buildFilterComplex(style, duration);
    this.logger.debug(`[generateVideo] filter_complex:\n${filter}`);

    const args = [
      '-y',
      '-loop', '1', '-i', coverPath,   // Input 0: cover
      '-i', audioPath,                   // Input 1: audio
      '-i', waveformPath,               // Input 2: waveform
      '-filter_complex', filter,
      '-map', '[vout]',
      '-map', '1:a',
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '26',
      '-maxrate', '4M',
      '-bufsize', '8M',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-t', String(duration),
      '-shortest',
      '-movflags', '+faststart',
      outputPath,
    ];

    this.logger.log(`[generateVideo] style=${style} duration=${duration}s`);
    const { stderr } = await exec('ffmpeg', args, { timeout: 300_000 });
    if (stderr) this.logger.debug(`[generateVideo] ${stderr.slice(0, 500)}`);

    const info = await fsStat(outputPath);
    this.logger.log(`[generateVideo] output size=${(info.size / 1024 / 1024).toFixed(1)}MB`);

    await this.cleanup(waveformPath);
  }

  // ── Waveform color per style ──────────────────────────────
  private waveformColor(style: VideoStyle): string {
    switch (style) {
      case 'zoom':   return '0xFFAA33AA';
      case 'night':  return '0x6699FFAA';
      case 'energy': return '0xFF5533CC';
      case 'sad':    return '0xCCBBAA88';
    }
  }

  // ══════════════════════════════════════════════════════════
  // FILTER COMPLEX
  // ══════════════════════════════════════════════════════════

  private buildFilterComplex(style: VideoStyle, duration: number): string {
    const W = 1080;
    const H = 1920;
    const fps = 30;
    const d = duration;
    const tf = d * fps;

    // Background: 1.5x for zoom headroom
    const bgW = Math.round(W * 1.5);
    const bgH = Math.round(H * 1.5);
    const bgScale = `[0:v]scale=${bgW}:${bgH}:force_original_aspect_ratio=increase,` +
      `crop=${bgW}:${bgH},setsar=1[bg_scaled]`;

    // Foreground cover
    const fgSize = 700;
    const fgScale = `[0:v]scale=${fgSize}:${fgSize}:force_original_aspect_ratio=decrease,` +
      `pad=${fgSize}:${fgSize}:(ow-iw)/2:(oh-ih)/2:color=black@0,setsar=1[fg_scaled]`;

    // Waveform position: full width at bottom
    const waveY = H - 100 - 160;
    const waveX = 0;

    switch (style) {
      case 'zoom':   return this.zoomFilter(bgScale, fgScale, W, H, d, fps, tf, fgSize, waveX, waveY);
      case 'night':  return this.nightFilter(bgScale, fgScale, W, H, d, fps, tf, fgSize, waveX, waveY);
      case 'energy': return this.energyFilter(bgScale, fgScale, W, H, d, fps, tf, fgSize, waveX, waveY);
      case 'sad':    return this.sadFilter(bgScale, fgScale, W, H, d, fps, tf, fgSize, waveX, waveY);
    }
  }

  // ── Glow from fg via split ────────────────────────────────
  private glowFromFg(opts: {
    fgSize: number; glowPad: number; sigma: number;
    bright: number; alpha: number;
    sat?: number; contrast?: number; extraFilter?: string;
  }): { fgSplit: string; glowFilter: string } {
    const { fgSize, glowPad, sigma, bright, alpha, sat, contrast, extraFilter } = opts;
    const glowSize = fgSize + glowPad;
    let eqParams = `brightness=${bright}`;
    if (sat !== undefined) eqParams += `:saturation=${sat}`;
    if (contrast !== undefined) eqParams += `:contrast=${contrast}`;
    const extra = extraFilter ? `,${extraFilter}` : '';
    return {
      fgSplit: `[fg_zoomed]split[fg][glow_src]`,
      glowFilter:
        `[glow_src]scale=${glowSize}:${glowSize}:flags=bilinear,` +
        `gblur=sigma=${sigma},eq=${eqParams}${extra},` +
        `format=rgba,colorchannelmixer=aa=${alpha}[glow]`,
    };
  }

  // ── Compose all layers ────────────────────────────────────
  private composeAll(
    lines: string[],
    W: number, H: number, fgSize: number, glowPad: number,
    waveX: number, waveY: number, waveAlpha: number,
    postFilters: string,
  ): void {
    const glowSize = fgSize + glowPad;
    const glowX = Math.floor((W - glowSize) / 2);
    const glowY = Math.floor((H - glowSize) / 2) - 80;
    const fgX = Math.floor((W - fgSize) / 2);
    const fgY = Math.floor((H - fgSize) / 2) - 80;

    lines.push(`[bg][glow]overlay=${glowX}:${glowY}:format=auto[bg_glow]`);
    lines.push(`[bg_glow][fg]overlay=${fgX}:${fgY}:format=auto[composed]`);
    lines.push(`[2:v]format=rgba,colorchannelmixer=aa=${waveAlpha}[wave]`);
    lines.push(`[composed][wave]overlay=${waveX}:${waveY}:format=auto:shortest=1[with_wave]`);
    lines.push(`[with_wave]${postFilters}[graded]`);
    lines.push(this.watermarkFrom('graded'));
  }

  // ══════════════════════════════════════════════════════════
  // ZOOM — smooth zoom + gentle pan + warm glow
  // ══════════════════════════════════════════════════════════
  private zoomFilter(
    bgScale: string, fgScale: string,
    W: number, H: number, d: number, fps: number, tf: number,
    fgSize: number, waveX: number, waveY: number,
  ): string {
    const lines: string[] = [];

    lines.push(bgScale);
    lines.push(
      `[bg_scaled]zoompan=` +
      `z='1+0.2*on/${tf}':` +
      `x='iw/2-(iw/zoom/2)+15*sin(2*PI*on/${tf}*0.7)':` +
      `y='ih/2-(ih/zoom/2)+10*cos(2*PI*on/${tf}*0.5)':` +
      `d=${tf}:s=${W}x${H}:fps=${fps},` +
      `boxblur=30:5,eq=brightness=-0.15:saturation=0.9[bg]`
    );

    lines.push(fgScale);
    lines.push(
      `[fg_scaled]zoompan=` +
      `z='1+0.1*on/${tf}':` +
      `x='iw/2-(iw/zoom/2)+8*sin(2*PI*on/${tf}*0.4)':` +
      `y='ih/2-(ih/zoom/2)+5*cos(2*PI*on/${tf}*0.3)':` +
      `d=${tf}:s=${fgSize}x${fgSize}:fps=${fps}[fg_zoomed]`
    );

    const glow = this.glowFromFg({ fgSize, glowPad: 80, sigma: 40, bright: 0.15, alpha: 0.45, sat: 1.5 });
    lines.push(glow.fgSplit);
    lines.push(glow.glowFilter);

    this.composeAll(lines, W, H, fgSize, 80, waveX, waveY, 0.6,
      `vignette=PI/4:mode=forward,` +
      `noise=alls=8:allf=t,` +
      `fade=t=in:st=0:d=1.2,fade=t=out:st=${d - 1.5}:d=1.5`
    );

    return lines.join(';');
  }

  // ══════════════════════════════════════════════════════════
  // NIGHT — cold tones, grain, vignette
  // ══════════════════════════════════════════════════════════
  private nightFilter(
    bgScale: string, fgScale: string,
    W: number, H: number, d: number, fps: number, tf: number,
    fgSize: number, waveX: number, waveY: number,
  ): string {
    const lines: string[] = [];

    lines.push(bgScale);
    lines.push(
      `[bg_scaled]zoompan=` +
      `z='1+0.08*on/${tf}':` +
      `x='iw/2-(iw/zoom/2)+12*sin(2*PI*on/${tf}*0.3)':` +
      `y='ih/2-(ih/zoom/2)+8*cos(2*PI*on/${tf}*0.4)':` +
      `d=${tf}:s=${W}x${H}:fps=${fps},` +
      `boxblur=35:5,eq=brightness=-0.2:saturation=0.5,` +
      `colorbalance=bs=0.2:bm=0.15:bh=0.1:rs=-0.08:rm=-0.05[bg]`
    );

    lines.push(fgScale);
    lines.push(
      `[fg_scaled]zoompan=` +
      `z='1+0.05*on/${tf}':` +
      `x='iw/2-(iw/zoom/2)+5*sin(2*PI*on/${tf}*0.35)':` +
      `y='ih/2-(ih/zoom/2)+4*cos(2*PI*on/${tf}*0.25)':` +
      `d=${tf}:s=${fgSize}x${fgSize}:fps=${fps},` +
      `eq=brightness=-0.06:saturation=0.8,colorbalance=bs=0.1:bm=0.06[fg_zoomed]`
    );

    const glow = this.glowFromFg({ fgSize, glowPad: 100, sigma: 50, bright: 0.08, alpha: 0.35, extraFilter: 'colorbalance=bs=0.3:bm=0.2' });
    lines.push(glow.fgSplit);
    lines.push(glow.glowFilter);

    this.composeAll(lines, W, H, fgSize, 100, waveX, waveY, 0.5,
      `vignette=PI/3.5:mode=forward,` +
      `noise=alls=30:allf=t+u,eq=brightness=-0.03,` +
      `fade=t=in:st=0:d=2,fade=t=out:st=${d - 2}:d=2`
    );

    return lines.join(';');
  }

  // ══════════════════════════════════════════════════════════
  // ENERGY — fast zoom, shake, flashes, contrast
  // ══════════════════════════════════════════════════════════
  private energyFilter(
    bgScale: string, fgScale: string,
    W: number, H: number, d: number, fps: number, tf: number,
    fgSize: number, waveX: number, waveY: number,
  ): string {
    const lines: string[] = [];

    lines.push(bgScale);
    lines.push(
      `[bg_scaled]zoompan=` +
      `z='1+0.3*on/${tf}':` +
      `x='iw/2-(iw/zoom/2)+22*sin(2*PI*on/${tf}*2.5)':` +
      `y='ih/2-(ih/zoom/2)+18*cos(2*PI*on/${tf}*3.1)':` +
      `d=${tf}:s=${W}x${H}:fps=${fps},` +
      `boxblur=20:3,eq=contrast=1.4:brightness=0.05:saturation=1.4[bg]`
    );

    lines.push(fgScale);
    lines.push(
      `[fg_scaled]zoompan=` +
      `z='1+0.18*on/${tf}':` +
      `x='iw/2-(iw/zoom/2)+12*sin(2*PI*on/${tf}*2.2)':` +
      `y='ih/2-(ih/zoom/2)+10*cos(2*PI*on/${tf}*2.8)':` +
      `d=${tf}:s=${fgSize}x${fgSize}:fps=${fps},` +
      `eq=contrast=1.25:saturation=1.3:brightness='0.04*sin(2*PI*t*1.2)'[fg_zoomed]`
    );

    const glow = this.glowFromFg({ fgSize, glowPad: 120, sigma: 45, bright: 0.25, alpha: 0.5, sat: 1.8, contrast: 1.3 });
    lines.push(glow.fgSplit);
    lines.push(glow.glowFilter);

    this.composeAll(lines, W, H, fgSize, 120, waveX, waveY, 0.75,
      `eq=brightness='0.06*sin(2*PI*t*1.8)':contrast=1.15,` +
      `vignette=PI/5:mode=forward,noise=alls=12:allf=t,` +
      `fade=t=in:st=0:d=0.5,fade=t=out:st=${d - 0.8}:d=0.8`
    );

    return lines.join(';');
  }

  // ══════════════════════════════════════════════════════════
  // SAD — slow, desaturated, fading
  // ══════════════════════════════════════════════════════════
  private sadFilter(
    bgScale: string, fgScale: string,
    W: number, H: number, d: number, fps: number, tf: number,
    fgSize: number, waveX: number, waveY: number,
  ): string {
    const lines: string[] = [];

    lines.push(bgScale);
    lines.push(
      `[bg_scaled]zoompan=` +
      `z='1+0.06*on/${tf}':` +
      `x='iw/2-(iw/zoom/2)+8*sin(2*PI*on/${tf}*0.2)':` +
      `y='ih/2-(ih/zoom/2)+5*cos(2*PI*on/${tf}*0.15)':` +
      `d=${tf}:s=${W}x${H}:fps=${fps},` +
      `boxblur=35:6,eq=brightness=-0.1:saturation=0.4,` +
      `colorbalance=rs=0.06:rm=0.03:rh=0.02[bg]`
    );

    lines.push(fgScale);
    lines.push(
      `[fg_scaled]zoompan=` +
      `z='1+0.03*on/${tf}':` +
      `x='iw/2-(iw/zoom/2)+4*sin(2*PI*on/${tf}*0.18)':` +
      `y='ih/2-(ih/zoom/2)+3*cos(2*PI*on/${tf}*0.12)':` +
      `d=${tf}:s=${fgSize}x${fgSize}:fps=${fps},` +
      `eq=brightness=-0.04:saturation=0.65[fg_zoomed]`
    );

    const glow = this.glowFromFg({ fgSize, glowPad: 100, sigma: 55, bright: 0.06, alpha: 0.3, sat: 0.5 });
    lines.push(glow.fgSplit);
    lines.push(glow.glowFilter);

    this.composeAll(lines, W, H, fgSize, 100, waveX, waveY, 0.35,
      `gblur=sigma=1.5,vignette=PI/3:mode=forward,` +
      `noise=alls=15:allf=t+u,` +
      `fade=t=in:st=0:d=2.5,fade=t=out:st=${d - 3}:d=3`
    );

    return lines.join(';');
  }

  // ── Watermark ─────────────────────────────────────────────
  private watermarkFrom(input: string): string {
    return `[${input}]drawtext=text='AURIX':` +
      `fontsize=28:fontcolor=white@0.2:` +
      `x=w-tw-30:y=h-th-40:` +
      `fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf[vout]`;
  }

  // ── Cleanup ───────────────────────────────────────────────
  async cleanup(...files: string[]): Promise<void> {
    for (const f of files) {
      try { await unlink(f); } catch { /* ignore */ }
    }
  }
}
