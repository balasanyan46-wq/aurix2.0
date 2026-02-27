class DnkSession {
  final String id;
  final String userId;
  final String status;
  final DateTime startedAt;
  final DateTime? finishedAt;

  const DnkSession({
    required this.id,
    required this.userId,
    required this.status,
    required this.startedAt,
    this.finishedAt,
  });

  factory DnkSession.fromJson(Map<String, dynamic> j) => DnkSession(
        id: (j['id'] ?? '').toString(),
        userId: (j['user_id'] ?? '').toString(),
        status: (j['status'] ?? 'in_progress').toString(),
        startedAt: DateTime.tryParse((j['started_at'] ?? '').toString()) ?? DateTime.now(),
        finishedAt: j['finished_at'] != null
            ? DateTime.tryParse(j['finished_at'].toString())
            : null,
      );
}

class DnkAxes {
  final Map<String, int> values;
  final Map<String, double> confidence;

  const DnkAxes({required this.values, required this.confidence});

  /// Handles two confidence formats:
  ///   Worker response: {"overall": 0.8, "by_axis": {"energy": 0.8, ...}}
  ///   DB (dnk_results): {"energy": 0.8, ...}  (flat)
  factory DnkAxes.fromJson(Map<String, dynamic> axes, Map<String, dynamic> conf) {
    final parsedValues = <String, int>{};
    for (final e in axes.entries) {
      if (e.value is num) {
        parsedValues[e.key] = (e.value as num).toInt();
      }
    }

    Map<String, dynamic> flatConf = conf;
    if (conf.containsKey('by_axis') && conf['by_axis'] is Map<String, dynamic>) {
      flatConf = conf['by_axis'] as Map<String, dynamic>;
    }
    final parsedConf = <String, double>{};
    for (final e in flatConf.entries) {
      if (e.value is num) {
        parsedConf[e.key] = (e.value as num).toDouble();
      }
    }

    return DnkAxes(values: parsedValues, confidence: parsedConf);
  }

  int operator [](String axis) => values[axis] ?? 50;
}

class DnkSocialAxes {
  final Map<String, int> values;

  const DnkSocialAxes({required this.values});

  factory DnkSocialAxes.fromJson(Map<String, dynamic>? raw) {
    final parsed = <String, int>{};
    if (raw != null) {
      for (final e in raw.entries) {
        if (e.value is num) {
          parsed[e.key] = (e.value as num).toInt();
        }
      }
    }
    return DnkSocialAxes(values: parsed);
  }

  int operator [](String axis) => values[axis] ?? 50;
}

class DnkSocialScripts {
  final List<String> hateReply;
  final List<String> interviewStyle;
  final List<String> conflictStyle;
  final List<String> teamworkRule;

  const DnkSocialScripts({
    required this.hateReply,
    required this.interviewStyle,
    required this.conflictStyle,
    required this.teamworkRule,
  });

  factory DnkSocialScripts.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const DnkSocialScripts(hateReply: [], interviewStyle: [], conflictStyle: [], teamworkRule: []);
    return DnkSocialScripts(
      hateReply: _safeStringList(j['hate_reply']),
      interviewStyle: _safeStringList(j['interview_style']),
      conflictStyle: _safeStringList(j['conflict_style']),
      teamworkRule: _safeStringList(j['teamwork_rule']),
    );
  }
}

class DnkSocialSummary {
  final List<String> magnets;
  final List<String> repellers;
  final String peopleComeFor;
  final String peopleLeaveWhen;
  final List<String> taboos;
  final DnkSocialScripts scripts;

  const DnkSocialSummary({
    required this.magnets,
    required this.repellers,
    required this.peopleComeFor,
    required this.peopleLeaveWhen,
    required this.taboos,
    required this.scripts,
  });

  factory DnkSocialSummary.fromJson(Map<String, dynamic>? j) {
    if (j == null) return DnkSocialSummary.empty();
    return DnkSocialSummary(
      magnets: _safeStringList(j['magnets']),
      repellers: _safeStringList(j['repellers']),
      peopleComeFor: (j['people_come_for'] ?? '').toString(),
      peopleLeaveWhen: (j['people_leave_when'] ?? '').toString(),
      taboos: _safeStringList(j['taboos']),
      scripts: DnkSocialScripts.fromJson(j['scripts'] is Map<String, dynamic> ? j['scripts'] as Map<String, dynamic> : null),
    );
  }

  factory DnkSocialSummary.empty() => const DnkSocialSummary(
        magnets: [],
        repellers: [],
        peopleComeFor: '',
        peopleLeaveWhen: '',
        taboos: [],
        scripts: DnkSocialScripts(hateReply: [], interviewStyle: [], conflictStyle: [], teamworkRule: []),
      );

  bool get isEmpty => magnets.isEmpty && repellers.isEmpty && taboos.isEmpty;
}

class DnkPassportHero {
  final String hook;
  final String howPeopleFeelYou;
  final List<String> magnet;
  final List<String> repulsion;
  final String shadow;
  final List<String> taboo;
  final List<String> next7Days;

  const DnkPassportHero({
    required this.hook,
    required this.howPeopleFeelYou,
    required this.magnet,
    required this.repulsion,
    required this.shadow,
    required this.taboo,
    required this.next7Days,
  });

  factory DnkPassportHero.fromJson(Map<String, dynamic>? j) {
    if (j == null) return DnkPassportHero.empty();
    return DnkPassportHero(
      hook: (j['hook'] ?? '').toString(),
      howPeopleFeelYou: (j['how_people_feel_you'] ?? '').toString(),
      magnet: _safeStringList(j['magnet']),
      repulsion: _safeStringList(j['repulsion']),
      shadow: (j['shadow'] ?? '').toString(),
      taboo: _safeStringList(j['taboo']),
      next7Days: _safeStringList(j['next_7_days']),
    );
  }

  factory DnkPassportHero.empty() => const DnkPassportHero(
        hook: '',
        howPeopleFeelYou: '',
        magnet: [],
        repulsion: [],
        shadow: '',
        taboo: [],
        next7Days: [],
      );

  bool get isEmpty => hook.isEmpty && shadow.isEmpty && magnet.isEmpty;
}

class DnkRecommendations {
  final Map<String, dynamic> music;
  final Map<String, dynamic> content;
  final Map<String, dynamic> behavior;
  final Map<String, dynamic> visual;

  const DnkRecommendations({
    required this.music,
    required this.content,
    required this.behavior,
    required this.visual,
  });

  factory DnkRecommendations.fromJson(Map<String, dynamic> j) => DnkRecommendations(
        music: (j['music'] as Map<String, dynamic>?) ?? {},
        content: (j['content'] as Map<String, dynamic>?) ?? {},
        behavior: (j['behavior'] as Map<String, dynamic>?) ?? {},
        visual: (j['visual'] as Map<String, dynamic>?) ?? {},
      );
}

class DnkPrompts {
  final String trackConcept;
  final String lyricsSeed;
  final String coverPrompt;
  final String reelsSeries;

  const DnkPrompts({
    required this.trackConcept,
    required this.lyricsSeed,
    required this.coverPrompt,
    required this.reelsSeries,
  });

  factory DnkPrompts.fromJson(Map<String, dynamic> j) => DnkPrompts(
        trackConcept: (j['track_concept'] ?? '').toString(),
        lyricsSeed: (j['lyrics_seed'] ?? '').toString(),
        coverPrompt: (j['cover_prompt'] ?? '').toString(),
        reelsSeries: (j['reels_series'] ?? '').toString(),
      );
}

class DnkResult {
  final String? resultId;
  final DnkAxes axes;
  final DnkSocialAxes socialAxes;
  final DnkSocialSummary socialSummary;
  final DnkPassportHero passportHero;
  final String profileText;
  final String profileShort;
  final String profileFull;
  final DnkRecommendations recommendations;
  final DnkPrompts prompts;
  final List<String> tags;
  final int regenCount;

  const DnkResult({
    this.resultId,
    required this.axes,
    required this.socialAxes,
    required this.socialSummary,
    required this.passportHero,
    required this.profileText,
    required this.profileShort,
    required this.profileFull,
    required this.recommendations,
    required this.prompts,
    required this.tags,
    required this.regenCount,
  });

  factory DnkResult.fromJson(Map<String, dynamic> j) {
    final axesRaw = (j['axes'] as Map<String, dynamic>?) ?? {};
    final confRaw = (j['confidence'] as Map<String, dynamic>?) ?? {};
    final socialAxesRaw = (j['social_axes'] as Map<String, dynamic>?) ?? {};
    final socialSummaryRaw = j['social_summary'] is Map<String, dynamic>
        ? j['social_summary'] as Map<String, dynamic>
        : null;
    final passportHeroRaw = j['passport_hero'] is Map<String, dynamic>
        ? j['passport_hero'] as Map<String, dynamic>
        : null;
    final recsRaw = (j['recommendations'] as Map<String, dynamic>?) ?? {};
    final promptsRaw = (j['prompts'] as Map<String, dynamic>?) ?? {};
    final tagsRaw = (j['tags'] as List?) ?? [];

    // social_summary / passport_hero might be nested inside recommendations (DB format)
    Map<String, dynamic>? socialFromRecs;
    if (socialSummaryRaw == null && recsRaw['social_summary'] is Map<String, dynamic>) {
      socialFromRecs = recsRaw['social_summary'] as Map<String, dynamic>;
    }
    Map<String, dynamic>? passportFromRecs;
    if (passportHeroRaw == null && recsRaw['passport_hero'] is Map<String, dynamic>) {
      passportFromRecs = recsRaw['passport_hero'] as Map<String, dynamic>;
    }

    return DnkResult(
      resultId: j['result_id']?.toString(),
      axes: DnkAxes.fromJson(axesRaw, confRaw),
      socialAxes: DnkSocialAxes.fromJson(socialAxesRaw),
      socialSummary: DnkSocialSummary.fromJson(socialSummaryRaw ?? socialFromRecs),
      passportHero: DnkPassportHero.fromJson(passportHeroRaw ?? passportFromRecs),
      profileText: (j['profile_text'] ?? '').toString(),
      profileShort: (j['profile_short'] ?? '').toString(),
      profileFull: (j['profile_full'] ?? '').toString(),
      recommendations: DnkRecommendations.fromJson(recsRaw),
      prompts: DnkPrompts.fromJson(promptsRaw),
      tags: tagsRaw.map((t) => t.toString()).toList(),
      regenCount: (j['regen_count'] is num) ? (j['regen_count'] as num).toInt() : 0,
    );
  }
}

/// Followup question returned by /dnk/answer
class DnkFollowup {
  final String id;
  final String type;
  final String text;
  final List<DnkQuestionOption>? options;
  final DnkScaleLabels? scaleLabels;

  const DnkFollowup({
    required this.id,
    required this.type,
    required this.text,
    this.options,
    this.scaleLabels,
  });

  factory DnkFollowup.fromJson(Map<String, dynamic> j) {
    DnkScaleLabels? labels;
    if (j['scaleLabels'] is Map<String, dynamic>) {
      labels = DnkScaleLabels.fromJson(j['scaleLabels'] as Map<String, dynamic>);
    } else if (j['scale'] is Map<String, dynamic>) {
      final s = j['scale'] as Map<String, dynamic>;
      final arr = s['labels'];
      if (arr is List && arr.length >= 5) {
        labels = DnkScaleLabels(
          low: arr.first?.toString() ?? '1',
          high: arr.last?.toString() ?? '5',
        );
      }
    }

    return DnkFollowup(
      id: (j['id'] ?? '').toString(),
      type: (j['type'] ?? 'scale').toString(),
      text: (j['text'] ?? '').toString(),
      options: (j['options'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(DnkQuestionOption.fromJson)
          .toList(),
      scaleLabels: labels,
    );
  }
}

class DnkQuestionOption {
  final String key;
  final String text;

  const DnkQuestionOption({required this.key, required this.text});

  factory DnkQuestionOption.fromJson(Map<String, dynamic> j) => DnkQuestionOption(
        key: (j['key'] ?? j['id'] ?? '').toString(),
        text: (j['text'] ?? j['label'] ?? '').toString(),
      );
}

class DnkScaleLabels {
  final String low;
  final String high;

  const DnkScaleLabels({required this.low, required this.high});

  factory DnkScaleLabels.fromJson(Map<String, dynamic> j) => DnkScaleLabels(
        low: (j['low'] ?? '1').toString(),
        high: (j['high'] ?? '5').toString(),
      );
}

List<String> _safeStringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return [];
}
