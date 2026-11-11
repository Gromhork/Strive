import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Curated German names of the most common exercises (all exercises of the built-in
/// programs plus the usual gym, home and bodyweight lifts). The base movement comes first
/// and the equipment in brackets, so "Bankdr…" finds every bench press variant together.
/// The English database name stays searchable as an alias.
const exerciseNamesDe = <String, String>{
  // ── Chest ──
  '0025': 'Bankdrücken (Langhantel)',
  '0289': 'Bankdrücken (Kurzhantel)',
  '0748': 'Bankdrücken (Multipresse)',
  '0151': 'Bankdrücken (Kabelzug)',
  '1254': 'Bankdrücken (Band)',
  '0122': 'Bankdrücken breiter Griff (Langhantel)',
  '0030': 'Enges Bankdrücken (Langhantel)',
  '0047': 'Schrägbankdrücken (Langhantel)',
  '0314': 'Schrägbankdrücken (Kurzhantel)',
  '0757': 'Schrägbankdrücken (Multipresse)',
  '0169': 'Schrägbankdrücken (Kabelzug)',
  '0033': 'Negativbankdrücken (Langhantel)',
  '0753': 'Negativbankdrücken (Multipresse)',
  '0577': 'Brustpresse (Maschine)',
  '0576': 'Brustpresse (Maschine, Variante)',
  '0308': 'Fliegende (Kurzhantel)',
  '0319': 'Schräge Fliegende (Kurzhantel)',
  '0302': 'Negative Fliegende (Kurzhantel)',
  '0227': 'Fliegende stehend (Kabelzug)',
  '0179': 'Fliegende von unten (Kabelzug)',
  '0188': 'Fliegende mittig (Kabelzug)',
  '0171': 'Schräge Fliegende (Kabelzug)',
  '0596': 'Butterfly (Maschine)',
  '0662': 'Liegestütz',
  '0493': 'Liegestütz erhöht (Hände auf Bank)',
  '0279': 'Liegestütz mit erhöhten Füßen',
  '0283': 'Diamant-Liegestütz',
  '0259': 'Enge Liegestütz',
  '0659': 'Liegestütz an der Wand',
  '0251': 'Dips (Brust)',
  '0375': 'Überzüge (Kurzhantel)',
  '0073': 'Überzüge (Langhantel)',
  // ── Back ──
  '0652': 'Klimmzug',
  '1429': 'Klimmzug breiter Griff',
  '0017': 'Klimmzug unterstützt (Maschine)',
  '0970': 'Klimmzug mit Band',
  '0841': 'Klimmzug mit Zusatzgewicht',
  '0688': 'Schulterblatt-Klimmzug',
  '1326': 'Klimmzug im Untergriff (Chin-up)',
  '1327': 'Enger Klimmzug im Untergriff',
  '0572': 'Untergriff-Klimmzug unterstützt (Maschine)',
  '2330': 'Latziehen (Kabelzug)',
  '0198': 'Latziehen (Kabelzug, Variante)',
  '0245': 'Latziehen im Untergriff (Kabelzug)',
  '0579': 'Latziehen (Maschine)',
  '0238': 'Latziehen mit gestreckten Armen (Kabelzug)',
  '0027': 'Rudern vorgebeugt (Langhantel)',
  '3017': 'Pendlay-Rudern (Langhantel)',
  '0293': 'Rudern vorgebeugt (Kurzhantel)',
  '0861': 'Rudern sitzend (Kabelzug)',
  '1350': 'Rudern sitzend (Maschine)',
  '0606': 'T-Bar-Rudern (Maschine)',
  '0581': 'Hohes Rudern (Maschine)',
  '0499': 'Rudern am Körpergewicht (umgekehrt)',
  '0808': 'Rudern im Schlingentrainer',
  '0032': 'Kreuzheben (Langhantel)',
  '0300': 'Kreuzheben (Kurzhantel)',
  '0811': 'Kreuzheben (Trap Bar)',
  '0117': 'Sumo-Kreuzheben (Langhantel)',
  '0085': 'Rumänisches Kreuzheben (Langhantel)',
  '1459': 'Rumänisches Kreuzheben (Kurzhantel)',
  '0432': 'Kreuzheben mit gestreckten Beinen (Kurzhantel)',
  '1757': 'Einbeiniges Kreuzheben (Kurzhantel)',
  '1756': 'Einbeiniges Kreuzheben (Langhantel)',
  '0489': 'Hyperextensions (Rückenstrecken)',
  '0573': 'Rückenstrecker (Maschine)',
  '0044': 'Good Morning (Langhantel)',
  '0095': 'Schulterheben (Langhantel)',
  '0406': 'Schulterheben (Kurzhantel)',
  '0604': 'Schulterheben (Maschine)',
  '0203': 'Face Pull / Rudern zum Gesicht (Seil)',
  // ── Shoulders ──
  '0426': 'Schulterdrücken stehend (Kurzhantel)',
  '0405': 'Schulterdrücken sitzend (Kurzhantel)',
  '0091': 'Schulterdrücken sitzend (Langhantel)',
  '1457': 'Schulterdrücken stehend (Langhantel)',
  '0603': 'Schulterdrücken (Maschine)',
  '0997': 'Schulterdrücken (Band)',
  '2137': 'Arnold Press (Kurzhantel)',
  '0334': 'Seitheben (Kurzhantel)',
  '0178': 'Seitheben (Kabelzug)',
  '0978': 'Frontheben (Band)',
  '0162': 'Frontheben (Kabelzug)',
  '0041': 'Frontheben (Langhantel)',
  '0378': 'Reverse Flys (Kurzhantel)',
  '0993': 'Reverse Flys (Band)',
  '0120': 'Aufrechtes Rudern (Langhantel)',
  '0246': 'Aufrechtes Rudern (Kabelzug)',
  '0471': 'Handstand-Liegestütz',
  // ── Arms ──
  '0031': 'Bizepscurl (Langhantel)',
  '0447': 'Bizepscurl (SZ-Stange)',
  '0294': 'Bizepscurl (Kurzhantel)',
  '0285': 'Bizepscurl abwechselnd (Kurzhantel)',
  '0313': 'Hammercurl (Kurzhantel)',
  '0318': 'Schrägbank-Curl (Kurzhantel)',
  '0297': 'Konzentrationscurl (Kurzhantel)',
  '0070': 'Scottcurl (Langhantel)',
  '0372': 'Scottcurl (Kurzhantel)',
  '0868': 'Bizepscurl (Kabelzug)',
  '0575': 'Bizepscurl (Maschine)',
  '0241': 'Trizepsdrücken (Kabelzug, V-Griff)',
  '0201': 'Trizepsdrücken (Kabelzug)',
  '0207': 'Trizepsdrücken im Untergriff (Kabelzug)',
  '0194': 'Trizepsdrücken über Kopf (Kabelzug, Seil)',
  '0061': 'French Press / Stirndrücken (Langhantel)',
  '0060': 'Stirndrücken / Skull Crusher (Langhantel)',
  '2188': 'Trizepsdrücken über Kopf sitzend (Kurzhantel)',
  '0333': 'Trizeps-Kickback (Kurzhantel)',
  '0607': 'Trizepsstrecken (Maschine)',
  '0814': 'Dips (Trizeps)',
  '0129': 'Bankdips (Knie gebeugt)',
  '1399': 'Dips am Boden',
  '0126': 'Handgelenkcurl (Langhantel)',
  '2133': "Farmer's Walk (Kurzhantel)",
  // ── Legs ──
  '0043': 'Kniebeuge (Langhantel)',
  '0042': 'Frontkniebeuge (Langhantel)',
  '0413': 'Kniebeuge (Kurzhantel)',
  '0770': 'Kniebeuge (Multipresse)',
  '1760': 'Goblet Squat (Kurzhantel)',
  '0534': 'Goblet Squat (Kettlebell)',
  '0743': 'Hackenschmidt-Kniebeuge (Maschine)',
  '0046': 'Hackenschmidt-Kniebeuge (Langhantel)',
  '0514': 'Sprungkniebeuge',
  '1004': 'Kniebeuge (Band)',
  '1489': 'Sissy Squat',
  '2368': 'Split Squat',
  '0410': 'Bulgarische Kniebeuge (Kurzhantel)',
  '0739': 'Beinpresse 45° (Maschine)',
  '0760': 'Beinpresse (Multipresse)',
  '0585': 'Beinstrecker (Maschine)',
  '0586': 'Beinbeuger liegend (Maschine)',
  '0599': 'Beinbeuger sitzend (Maschine)',
  '0336': 'Ausfallschritt (Kurzhantel)',
  '0054': 'Ausfallschritt (Langhantel)',
  '0381': 'Ausfallschritt rückwärts (Kurzhantel)',
  '0078': 'Ausfallschritt rückwärts (Langhantel)',
  '1460': 'Gehende Ausfallschritte',
  '0431': 'Step-ups (Kurzhantel)',
  '0114': 'Step-ups (Langhantel)',
  '1409': 'Glute Bridge / Hüftheben (Langhantel)',
  '3013': 'Glute Bridge / Hüftheben',
  '3561': 'Glute Bridge mit Marschieren',
  '0597': 'Abduktoren (Maschine)',
  '0598': 'Adduktoren (Maschine)',
  '0860': 'Kickback für das Gesäß (Kabelzug)',
  '0605': 'Wadenheben stehend (Maschine)',
  '0594': 'Wadenheben sitzend (Maschine)',
  '0409': 'Einbeiniges Wadenheben (Kurzhantel)',
  '1373': 'Wadenheben stehend',
  '0284': 'Esel-Wadenheben',
  '3193': 'Glute-Ham Raise',
  // ── Core ──
  '0274': 'Crunch',
  '0872': 'Reverse Crunch',
  '0277': 'Crunch auf der Schrägbank',
  '0212': 'Crunch sitzend (Kabelzug)',
  '0832': 'Crunch mit Gewicht',
  '0262': 'Diagonaler Crunch',
  '0003': 'Fahrrad-Crunch',
  '0472': 'Hängendes Beinheben',
  '0689': 'Beinheben sitzend',
  '0687': 'Russian Twist',
  '0846': 'Russian Twist mit Gewicht',
  '0276': 'Dead Bug',
  '2135': 'Unterarmstütz / Plank mit Gewicht',
  '0464': 'Unterarmstütz mit Drehung',
  '3544': 'Seitstütz erhöht',
  '0705': 'Seitstütz',
  '0282': 'Sit-up auf der Schrägbank',
  '0001': 'Sit-up',
  '0630': 'Bergsteiger (Mountain Climber)',
  '0243': 'Rumpfdrehung (Kabelzug)',
  // ── Full body / conditioning ──
  '1160': 'Burpee',
  '0549': 'Kettlebell Swing',
  '3305': 'Thruster (Langhantel)',
  '0648': 'Power Clean (Langhantel)',
  '2612': 'Seilspringen',
};

/// The most used exercises (all of the built-in programs plus the classic gym lifts) –
/// ranked first in the search, before rarer variants such as band or Smith machine.
const commonExerciseIds = {
  // built-in programs
  '0025', '0027', '0031', '0032', '0043', '0085', '0129', '0178', '0194', '0227', '0241', '0276', '0289', '0293', '0313', '0314',
  '0318', '0334', '0336', '0378', '0381', '0405', '0409', '0410', '0426', '0472', '0499', '0514', '0585', '0586', '0594', '0599',
  '0605', '0630', '0652', '0662', '0739', '0814', '0861', '1326', '1373', '1459', '1460', '1757', '1760', '2330', '3561',
  // classic lifts
  '0042', '0047', '0030', '0091', '1457', '0070', '0294', '0603', '0577', '0596', '0201', '0308', '0095', '0406', '0274', '0687',
  '0300', '0811', '0117', '0046', '0743', '0054', '1409', '0597', '0598', '2137', '0297', '0061', '0333', '0549',
};

/// German names of the muscles, body parts and equipment of the database.
const muscleNamesDe = <String, String>{
  'abdominals': 'Bauchmuskeln',
  'ankle stabilizers': 'Sprunggelenk-Stabilisatoren',
  'ankles': 'Sprunggelenke',
  'back': 'Rücken',
  'brachialis': 'Oberarmmuskel (Brachialis)',
  'chest': 'Brust',
  'core': 'Rumpf',
  'deltoids': 'Deltamuskel',
  'feet': 'Füße',
  'grip muscles': 'Griffkraft',
  'groin': 'Leiste',
  'hands': 'Hände',
  'hip flexors': 'Hüftbeuger',
  'inner thighs': 'Innenseite Oberschenkel',
  'latissimus dorsi': 'Latissimus',
  'lower abs': 'Untere Bauchmuskeln',
  'lower back': 'Unterer Rücken',
  'obliques': 'Seitliche Bauchmuskeln',
  'quadriceps': 'Quadrizeps',
  'rear deltoids': 'Hintere Schulter',
  'rhomboids': 'Rautenmuskeln',
  'rotator cuff': 'Rotatorenmanschette',
  'shins': 'Schienbeine',
  'shoulders': 'Schultern',
  'soleus': 'Schollenmuskel (Wade)',
  'sternocleidomastoid': 'Kopfwender (Hals)',
  'trapezius': 'Trapez',
  'upper chest': 'Obere Brust',
  'wrist extensors': 'Handgelenkstrecker',
  'wrist flexors': 'Handgelenkbeuger',
  'wrists': 'Handgelenke',
};

/// Gemini translations of names without a curated entry (cached by the translation
/// service under `trn_de_<id>`); set once at start-up.
SharedPreferences? exerciseNamePrefs;

/// Display name of exercise [id] (English database name [en]) in [lang]: the curated
/// German name, else a cached translation, else a rule-based German name of the database
/// name ([germanExerciseName]) – never the raw English one (also for stored sessions).
String exerciseName(String id, String en, String lang) {
  if (lang == 'de') {
    final de = exerciseNamesDe[id] ?? exerciseNamePrefs?.getString('trn_de_$id');
    if (de != null && de.isNotEmpty) return de;
    // A name the user typed (custom exercise) or an already German name stays as it is.
    if (en.isNotEmpty && !_looksGerman(en)) return germanExerciseName(en);
  }
  return en.isEmpty ? en : en[0].toUpperCase() + en.substring(1);
}

bool _looksGerman(String s) => RegExp('[äöüß]|drücken|heben|beuge|rudern|ziehen', caseSensitive: false).hasMatch(s);

/// Equipment of the database names → German (in brackets after the movement).
const _equipmentDe = <(String, String)>[
  ('olympic barbell', 'Langhantel'),
  ('ez barbell', 'SZ-Stange'),
  ('ez bar', 'SZ-Stange'),
  ('trap bar', 'Trap Bar'),
  ('smith machine', 'Multipresse'),
  ('smith', 'Multipresse'),
  ('leverage machine', 'Maschine'),
  ('lever', 'Maschine'),
  ('sled', 'Maschine'),
  ('machine', 'Maschine'),
  ('barbell', 'Langhantel'),
  ('dumbbell', 'Kurzhantel'),
  ('cable', 'Kabelzug'),
  ('resistance band', 'Band'),
  ('band', 'Band'),
  ('kettlebell', 'Kettlebell'),
  ('stability ball', 'Gymnastikball'),
  ('exercise ball', 'Gymnastikball'),
  ('medicine ball', 'Medizinball'),
  ('bosu ball', 'Bosu'),
  ('rope', 'Seil'),
];

/// Movements (longest phrases first) → German.
const _movementDe = <(String, String)>[
  ('romanian deadlift', 'Rumänisches Kreuzheben'),
  ('stiff leg deadlift', 'Kreuzheben mit gestreckten Beinen'),
  ('sumo deadlift', 'Sumo-Kreuzheben'),
  ('deadlift', 'Kreuzheben'),
  ('incline bench press', 'Schrägbankdrücken'),
  ('decline bench press', 'Negativbankdrücken'),
  ('close grip bench press', 'Enges Bankdrücken'),
  ('bench press', 'Bankdrücken'),
  ('military press', 'Schulterdrücken'),
  ('shoulder press', 'Schulterdrücken'),
  ('overhead press', 'Schulterdrücken'),
  ('arnold press', 'Arnold Press'),
  ('chest press', 'Brustpresse'),
  ('leg press', 'Beinpresse'),
  ('floor press', 'Bodendrücken'),
  ('front squat', 'Frontkniebeuge'),
  ('hack squat', 'Hackenschmidt-Kniebeuge'),
  ('split squat', 'Split Squat'),
  ('goblet squat', 'Goblet Squat'),
  ('squat', 'Kniebeuge'),
  ('walking lunge', 'Gehende Ausfallschritte'),
  ('lunge', 'Ausfallschritt'),
  ('upright row', 'Aufrechtes Rudern'),
  ('row', 'Rudern'),
  ('lat pulldown', 'Latziehen'),
  ('pulldown', 'Latziehen'),
  ('pull-up', 'Klimmzug'),
  ('pull up', 'Klimmzug'),
  ('chin-up', 'Klimmzug im Untergriff'),
  ('chin up', 'Klimmzug im Untergriff'),
  ('push-up', 'Liegestütz'),
  ('push up', 'Liegestütz'),
  ('pushup', 'Liegestütz'),
  ('hammer curl', 'Hammercurl'),
  ('preacher curl', 'Scottcurl'),
  ('concentration curl', 'Konzentrationscurl'),
  ('wrist curl', 'Handgelenkcurl'),
  ('leg curl', 'Beinbeuger'),
  ('biceps curl', 'Bizepscurl'),
  ('bicep curl', 'Bizepscurl'),
  ('curl', 'Curl'),
  ('triceps extension', 'Trizepsstrecken'),
  ('tricep extension', 'Trizepsstrecken'),
  ('triceps pushdown', 'Trizepsdrücken'),
  ('pushdown', 'Trizepsdrücken'),
  ('skull crusher', 'Stirndrücken'),
  ('leg extension', 'Beinstrecker'),
  ('back extension', 'Rückenstrecken'),
  ('hyperextension', 'Rückenstrecken'),
  ('lateral raise', 'Seitheben'),
  ('side lateral raise', 'Seitheben'),
  ('front raise', 'Frontheben'),
  ('rear delt raise', 'Reverse Flys'),
  ('rear delt fly', 'Reverse Flys'),
  ('reverse fly', 'Reverse Flys'),
  ('calf raise', 'Wadenheben'),
  ('leg raise', 'Beinheben'),
  ('fly', 'Fliegende'),
  ('pullover', 'Überzüge'),
  ('shrug', 'Schulterheben'),
  ('kickback', 'Kickback'),
  ('crunch', 'Crunch'),
  ('sit-up', 'Sit-up'),
  ('sit up', 'Sit-up'),
  ('side plank', 'Seitstütz'),
  ('plank', 'Unterarmstütz'),
  ('dips', 'Dips'),
  ('dip', 'Dips'),
  ('hip thrust', 'Hip Thrust'),
  ('glute bridge', 'Glute Bridge'),
  ('bridge', 'Brücke'),
  ('good morning', 'Good Morning'),
  ('step-up', 'Step-up'),
  ('step up', 'Step-up'),
  ('russian twist', 'Russian Twist'),
  ('twist', 'Rumpfdrehung'),
  ('stretch', 'Dehnung'),
  ('rotation', 'Rotation'),
  ('jump', 'Sprung'),
  ('swing', 'Swing'),
  ('press', 'Drücken'),
  ('raise', 'Heben'),
];

/// Positions and variations → German (after the movement).
const _modifierDe = <(String, String)>[
  ('close grip', 'enger Griff'),
  ('close-grip', 'enger Griff'),
  ('wide grip', 'breiter Griff'),
  ('wide-grip', 'breiter Griff'),
  ('reverse grip', 'Untergriff'),
  ('neutral grip', 'Neutralgriff'),
  ('underhand', 'Untergriff'),
  ('one arm', 'einarmig'),
  ('single arm', 'einarmig'),
  ('one leg', 'einbeinig'),
  ('single leg', 'einbeinig'),
  ('two arm', 'beidarmig'),
  ('straight arm', 'mit gestreckten Armen'),
  ('bent over', 'vorgebeugt'),
  ('behind the head', 'hinter dem Kopf'),
  ('behind head', 'hinter dem Kopf'),
  ('behind neck', 'hinter dem Nacken'),
  ('alternating', 'abwechselnd'),
  ('alternate', 'abwechselnd'),
  ('seated', 'sitzend'),
  ('standing', 'stehend'),
  ('lying', 'liegend'),
  ('kneeling', 'kniend'),
  ('hanging', 'hängend'),
  ('incline', 'schräg'),
  ('decline', 'negativ'),
  ('weighted', 'mit Gewicht'),
  ('assisted', 'unterstützt'),
  ('overhead', 'über Kopf'),
  ('reverse', 'umgekehrt'),
  ('high', 'hoch'),
  ('low', 'tief'),
];

const _fillerWords = {'with', 'on', 'the', 'to', 'and', 'a', 'of', 'v', 'male', 'female', 'pov', 'version', 'exercise', 'body', 'weight', 'bodyweight'};

/// Rule-based German name of an English database name for exercises without a curated or
/// translated name: the movement first, then the variation, the equipment in brackets
/// ("dumbbell seated shoulder press" → "Schulterdrücken sitzend (Kurzhantel)"). Words it
/// does not know (proper names like "Zottman") are kept in front of the movement.
String germanExerciseName(String en) {
  var s = ' ${en.toLowerCase().replaceAll(RegExp(r'\(.*?\)|v\.\s*\d|\bv\d\b'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
  String? take(List<(String, String)> table) {
    for (final (k, v) in table) {
      final re = RegExp('(?<![a-z])${RegExp.escape(k)}s?(?![a-z])');
      if (re.hasMatch(s)) {
        s = s.replaceFirst(re, ' ');
        return v;
      }
    }
    return null;
  }

  final equipment = take(_equipmentDe);
  final movement = take(_movementDe);
  final mods = <String>[];
  for (var m = take(_modifierDe); m != null; m = take(_modifierDe)) {
    if (!mods.contains(m)) mods.add(m);
  }
  final rest = [
    for (final w in s.trim().split(RegExp(r'\s+')))
      if (w.isNotEmpty && !_fillerWords.contains(w) && !RegExp(r'^\d+$').hasMatch(w)) w[0].toUpperCase() + w.substring(1),
  ];
  if (movement == null && mods.isEmpty && equipment == null) return en.isEmpty ? en : en[0].toUpperCase() + en.substring(1);
  final head = [...rest, movement ?? ''].where((x) => x.isNotEmpty).join(' ');
  final name = [head.isEmpty ? (equipment ?? '') : head, ...mods].join(' ');
  return equipment == null || head.isEmpty ? name : '$name ($equipment)';
}

/// [exerciseName] in the language of [context].
String exName(BuildContext context, String id, String en) => exerciseName(id, en, Localizations.localeOf(context).languageCode);
