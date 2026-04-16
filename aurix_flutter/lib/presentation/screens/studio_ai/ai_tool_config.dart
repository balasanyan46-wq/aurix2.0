import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'studio_ai_screen.dart' show AiMode;

class AiToolConfig {
  final AiMode mode;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> examplePrompts;
  final bool isExternal; // opens separate screen, not chat

  const AiToolConfig({
    required this.mode,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.examplePrompts,
    this.isExternal = false,
  });
}

const List<AiToolConfig> aiTools = [
  AiToolConfig(
    mode: AiMode.chat,
    title: 'Чат',
    description: 'Свободный разговор с AI-продюсером',
    icon: Icons.chat_rounded,
    color: AurixTokens.accent,
    examplePrompts: [
      'Как раскрутить трек с нуля?',
      'Придумай название для альбома про одиночество',
      'Какие тренды в музыке сейчас?',
      'Как выбрать дистрибьютора?',
    ],
  ),
  AiToolConfig(
    mode: AiMode.lyrics,
    title: 'Текст',
    description: 'Генерация текстов и хуков',
    icon: Icons.edit_note_rounded,
    color: Color(0xFF8B5CF6),
    examplePrompts: [
      'Напиши текст про ночной город в стиле хип-хоп',
      'Придумай припев про расставание',
      'Хук для летнего трека',
      'Текст в стиле Oxxxymiron про амбиции',
    ],
  ),
  AiToolConfig(
    mode: AiMode.ideas,
    title: 'Идеи',
    description: '10 идей для треков за секунды',
    icon: Icons.lightbulb_rounded,
    color: AurixTokens.warning,
    examplePrompts: [
      'Идеи для дарк-поп трека',
      'Концепции для мини-альбома из 5 треков',
      'Идеи треков про деньги и успех',
      'Нестандартные темы для R&B',
    ],
  ),
  AiToolConfig(
    mode: AiMode.reels,
    title: 'Reels',
    description: 'Вирусные идеи для TikTok и Reels',
    icon: Icons.videocam_rounded,
    color: Color(0xFFEC4899),
    examplePrompts: [
      'Идеи Reels для продвижения нового трека',
      'Вирусный контент для хип-хоп артиста',
      'Reels-серия на неделю для разогрева аудитории',
      'Идеи для backstage контента',
    ],
  ),
  AiToolConfig(
    mode: AiMode.dnk,
    title: 'DNK',
    description: 'Анализ аудитории и стратегия',
    icon: Icons.fingerprint_rounded,
    color: AurixTokens.positive,
    examplePrompts: [
      'Проанализируй мою аудиторию как хип-хоп артиста',
      'Какие триггеры зацепят мою ЦА?',
      'Стратегия контента на месяц',
      'Мои сильные стороны как артиста',
    ],
  ),
  AiToolConfig(
    mode: AiMode.image,
    title: 'Обложка',
    description: 'AI-генерация обложек',
    icon: Icons.image_rounded,
    color: AurixTokens.aiAccent,
    examplePrompts: [
      'Обложка для дарк-трека: ночной город, неон',
      'Минималистичная обложка с закатом',
      'Обложка в стиле 90-х хип-хоп',
      'Абстрактная обложка для электронного трека',
    ],
    isExternal: true,
  ),
  AiToolConfig(
    mode: AiMode.analyze,
    title: 'Анализ',
    description: 'Стратегический разбор трека',
    icon: Icons.graphic_eq_rounded,
    color: AurixTokens.coolUndertone,
    examplePrompts: [],
    isExternal: true,
  ),
];
