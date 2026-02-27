/// User role for mock auth and admin visibility
enum UserRole { artist, admin }

/// Artist level — статусная иерархия (Rising → Pro → Top 100 → Elite)
enum ArtistLevel {
  rising,   // Index < 400
  pro,      // 400–600
  top100,   // Top 100 по рейтингу
  elite,    // Top 10
}

extension ArtistLevelX on ArtistLevel {
  String get label {
    switch (this) {
      case ArtistLevel.rising:
        return 'Rising';
      case ArtistLevel.pro:
        return 'Pro';
      case ArtistLevel.top100:
        return 'Top 100';
      case ArtistLevel.elite:
        return 'Elite';
    }
  }
}

/// Вычисляет уровень артиста по индексу и рангу.
ArtistLevel artistLevelFromScore(int score, int rankOverall) {
  if (rankOverall <= 10) return ArtistLevel.elite;
  if (rankOverall <= 100) return ArtistLevel.top100;
  if (score >= 600) return ArtistLevel.pro;
  if (score >= 400) return ArtistLevel.pro;
  return ArtistLevel.rising;
}

/// Subscription plan slugs stored in DB: start / breakthrough / empire
enum SubscriptionPlan {
  start,
  breakthrough,
  empire;

  /// DB slug = enum name
  String get slug => name;

  /// Russian display label
  String get label {
    switch (this) {
      case SubscriptionPlan.start: return 'Старт';
      case SubscriptionPlan.breakthrough: return 'Прорыв';
      case SubscriptionPlan.empire: return 'Империя';
    }
  }

  /// Resolve from DB string. Falls back to [start] for unknown/legacy values.
  static SubscriptionPlan fromSlug(String? raw) {
    switch (raw) {
      case 'start': return SubscriptionPlan.start;
      case 'breakthrough': return SubscriptionPlan.breakthrough;
      case 'empire': return SubscriptionPlan.empire;
      // legacy migration fallbacks
      case 'base': case 'basic': case 'BASE': return SubscriptionPlan.start;
      case 'pro': case 'PRO': return SubscriptionPlan.breakthrough;
      case 'studio': case 'STUDIO': return SubscriptionPlan.empire;
      default: return SubscriptionPlan.start;
    }
  }
}

/// Release status flow: Draft → In Review → Approved → Scheduled → Live
enum ReleaseStatus {
  draft,
  inReview,
  approved,
  rejected,
  scheduled,
  live,
}

extension ReleaseStatusX on ReleaseStatus {
  String get label {
    switch (this) {
      case ReleaseStatus.draft:
        return 'Черновик';
      case ReleaseStatus.inReview:
        return 'На проверке';
      case ReleaseStatus.approved:
        return 'Одобрен';
      case ReleaseStatus.rejected:
        return 'Отклонён';
      case ReleaseStatus.scheduled:
        return 'Запланирован';
      case ReleaseStatus.live:
        return 'Выпущен';
    }
  }
}

/// Maps Supabase release status string to ReleaseStatus
ReleaseStatus releaseStatusFromString(String s) {
  switch (s) {
    case 'draft':
      return ReleaseStatus.draft;
    case 'submitted':
      return ReleaseStatus.inReview;
    case 'approved':
      return ReleaseStatus.approved;
    case 'rejected':
      return ReleaseStatus.rejected;
    case 'scheduled':
      return ReleaseStatus.scheduled;
    case 'live':
      return ReleaseStatus.live;
    default:
      return ReleaseStatus.draft;
  }
}

/// Screen routing — used by AppState.currentScreen
enum AppScreen {
  home,
  releases,
  uploadRelease,
  releaseDetails,
  analytics,
  promotion,
  progress,
  studioAi,
  services,
  finances,
  team,
  subscription,
  support,
  settings,
  profile,
  aurixIndex,
  admin,
  legal,
  aurixDnk,
}
