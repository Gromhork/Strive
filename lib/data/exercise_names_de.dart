import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Curated German names of every exercise of the database (also of the ones hidden from
/// the library, so older sessions keep a German name). Format "Bewegung Variante
/// (Ausrüstung)": the base movement comes first in the usual German gym vocabulary and the
/// equipment in brackets, so "Bankdr…" finds every bench press variant together; well-known
/// English loanwords (Curl, Crunch, Dips, Face Pull, Good Morning …) are kept. Bodyweight
/// exercises have no bracket. The English database name stays searchable as an alias.
const exerciseNamesDe = <String, String>{
  '0001': 'Sit-up', // 3/4 sit-up
  '0002': 'Seitbeuge an der 45°-Bank', // 45° side bend
  '0003': 'Fahrrad-Crunch', // air bike
  '0006': 'Fersentippen abwechselnd', // alternate heel touchers
  '0007': 'Latziehen abwechselnd einarmig (Kabelzug)', // alternate lateral pulldown
  '0009': 'Brust-Dips kniend unterstützt (Maschine)', // assisted chest dip (kneeling)
  '0010': 'Knieheben hängend mit Partnerwurf', // assisted hanging knee raise with throw down
  '0011': 'Knieheben hängend mit Unterstützung', // assisted hanging knee raise
  '0012': 'Beinheben liegend mit seitlichem Partnerwurf', // assisted lying leg raise with lateral throw down
  '0013': 'Beinheben liegend mit Partnerwurf', // assisted lying leg raise with throw down
  '0014': 'Russian Twist geführt (Medizinball)', // assisted motion russian twist
  '0015': 'Klimmzug eng Neutralgriff unterstützt (Maschine)', // assisted parallel close grip pull-up
  '0016': 'Beinbeuger liegend mit Partner', // assisted prone hamstring
  '0017': 'Klimmzug unterstützt (Maschine)', // assisted pull-up
  '0018': 'Trizepsstrecken stehend mit Handtuch (Partner)', // assisted standing triceps extension (with towel)
  '0019': 'Trizeps-Dips kniend unterstützt (Maschine)', // assisted triceps dip (kneeling)
  '0020': 'Balance Board Stand', // balance board stand
  '0022': 'Überzüge mit Drücken (Langhantel)', // barbell pullover to press
  '0023': 'Bizepscurl abwechselnd (Langhantel)', // barbell alternate biceps curl
  '0024': 'Frontkniebeuge zur Bank (Langhantel)', // barbell bench front squat
  '0025': 'Bankdrücken (Langhantel)', // barbell bench press
  '0026': 'Kniebeuge zur Bank (Langhantel)', // barbell bench squat
  '0027': 'Rudern vorgebeugt (Langhantel)', // barbell bent over row
  '0028': 'Umsetzen und Drücken (Langhantel)', // barbell clean and press
  '0029': 'Frontkniebeuge im Umsetzgriff (Langhantel)', // barbell clean-grip front squat
  '0030': 'Bankdrücken eng (Langhantel)', // barbell close-grip bench press
  '0031': 'Bizepscurl (Langhantel)', // barbell curl
  '0032': 'Kreuzheben (Langhantel)', // barbell deadlift
  '0033': 'Negativbankdrücken (Langhantel)', // barbell decline bench press
  '0034': 'Überzüge mit gebeugten Armen auf der Negativbank (Langhantel)', // barbell decline bent arm pullover
  '0035': 'Negativbankdrücken eng zur Stirn (Langhantel)', // barbell decline close grip to skull press
  '0036': 'Negativbankdrücken breit (Langhantel)', // barbell decline wide-grip press
  '0037': 'Überzüge breit auf der Negativbank (Langhantel)', // barbell decline wide-grip pullover
  '0038': 'Drag Curl (Langhantel)', // barbell drag curl
  '0039': 'Frontkniebeuge mit verschränkten Armen (Langhantel)', // barbell front chest squat
  '0040': 'Frontheben mit Überzug (Langhantel)', // barbell front raise and pullover
  '0041': 'Frontheben (Langhantel)', // barbell front raise
  '0042': 'Frontkniebeuge (Langhantel)', // barbell front squat
  '0043': 'Kniebeuge (Langhantel)', // barbell full squat
  '0044': 'Good Morning (Langhantel)', // barbell good morning
  '0045': 'Guillotine-Bankdrücken (Langhantel)', // barbell guillotine bench press
  '0046': 'Hackenschmidt-Kniebeuge (Langhantel)', // barbell hack squat
  '0047': 'Schrägbankdrücken (Langhantel)', // barbell incline bench press
  '0048': 'Schrägbankdrücken Untergriff (Langhantel)', // barbell incline reverse-grip bench press
  '0049': 'Rudern bauchliegend auf der Schrägbank (Langhantel)', // barbell incline row
  '0050': 'Schulter-Protraktion auf der Schrägbank (Langhantel)', // barbell incline shoulder raise
  '0051': 'Jefferson-Kniebeuge (Langhantel)', // barbell jefferson squat
  '0052': 'JM Press (Langhantel)', // barbell jm bench press
  '0053': 'Sprungkniebeuge (Langhantel)', // barbell jump squat
  '0054': 'Ausfallschritt (Langhantel)', // barbell lunge
  '0055': 'Bankdrücken eng am Boden (Langhantel)', // barbell lying close-grip press
  '0056': 'French Press eng (Langhantel)', // barbell lying close-grip triceps extension
  '0057': 'Trizepsstrecken liegend (Langhantel)', // barbell lying extension
  '0058': 'Hüftheben liegend (Langhantel)', // barbell lying lifting (on hip)
  '0059': 'Scottcurl liegend (Langhantel)', // barbell lying preacher curl
  '0060': 'Stirndrücken / Skull Crusher (Langhantel)', // barbell lying triceps extension skull crusher
  '0061': 'French Press / Stirndrücken (Langhantel)', // barbell lying triceps extension
  '0063': 'Kniebeuge enger Stand (Langhantel)', // barbell narrow stance squat
  '0064': 'Rudern vorgebeugt einarmig (Langhantel)', // barbell one arm bent over row
  '0065': 'Bodendrücken einarmig (Langhantel)', // barbell one arm floor press
  '0066': 'Kreuzheben seitlich einarmig (Langhantel)', // barbell one arm side deadlift
  '0067': 'Reißen einarmig (Langhantel)', // barbell one arm snatch
  '0068': 'Kniebeuge einbeinig (Langhantel)', // barbell one leg squat
  '0069': 'Überkopfkniebeuge (Langhantel)', // barbell overhead squat
  '0070': 'Scottcurl (Langhantel)', // barbell preacher curl
  '0071': 'Sit-up mit Drücken (Langhantel)', // barbell press sit-up
  '0072': 'Curl bauchliegend auf der Schrägbank (Langhantel)', // barbell prone incline curl
  '0073': 'Überzüge (Langhantel)', // barbell pullover
  '0074': 'Rack Pull / Teilkreuzheben (Langhantel)', // barbell rack pull
  '0075': 'Reverse Flys vorgebeugt (Langhantel)', // barbell rear delt raise
  '0076': 'Rudern für die hintere Schulter (Langhantel)', // barbell rear delt row
  '0077': 'Ausfallschritt rückwärts (Langhantel, Variante 2)', // barbell rear lunge v. 2
  '0078': 'Ausfallschritt rückwärts (Langhantel)', // barbell rear lunge
  '0079': 'Handgelenkcurl Obergriff (Langhantel, Variante 2)', // barbell reverse wrist curl v. 2
  '0080': 'Reverse Curl / Curl im Obergriff (Langhantel)', // barbell reverse curl
  '0081': 'Scottcurl im Obergriff (Langhantel)', // barbell reverse preacher curl
  '0082': 'Handgelenkcurl Obergriff (Langhantel)', // barbell reverse wrist curl
  '0083': 'Rollout von der Bank (Langhantel)', // barbell rollout from bench
  '0084': 'Rollout kniend (Langhantel)', // barbell rollout
  '0085': 'Rumänisches Kreuzheben (Langhantel)', // barbell romanian deadlift
  '0086': 'Nackendrücken sitzend (Langhantel)', // barbell seated behind head military press
  '0087': 'Bradford Press sitzend (Langhantel)', // barbell seated bradford rocky press
  '0088': 'Wadenheben sitzend (Langhantel)', // barbell seated calf raise
  '0089': 'Konzentrationscurl eng sitzend (Langhantel)', // barbell seated close-grip concentration curl
  '0090': 'Good Morning sitzend (Langhantel)', // barbell seated good morning
  '0091': 'Schulterdrücken sitzend (Langhantel)', // barbell seated overhead press
  '0092': 'Trizepsdrücken über Kopf sitzend (Langhantel)', // barbell seated overhead triceps extension
  '0094': 'Rumpfdrehung sitzend (Langhantel)', // barbell seated twist
  '0095': 'Schulterheben (Langhantel)', // barbell shrug
  '0096': 'Seitbeuge (Langhantel)', // barbell side bend
  '0097': 'Seitliche Kniebeuge (Langhantel, Variante 2)', // barbell side split squat v. 2
  '0098': 'Seitliche Kniebeuge (Langhantel)', // barbell side split squat
  '0099': 'Bulgarische Kniebeuge (Langhantel)', // barbell single leg split squat
  '0100': 'Skier-Schwung (Langhantel)', // barbell skier
  '0101': 'Speed-Kniebeuge (Langhantel)', // barbell speed squat
  '0102': 'Kniebeuge kniend (Langhantel)', // barbell squat (on knees)
  '0103': 'Rollout stehend (Langhantel)', // barbell standing ab rollout
  '0104': 'Handgelenkcurl hinter dem Rücken (Langhantel)', // barbell standing back wrist curl
  '0105': 'Bradford Press stehend (Langhantel)', // barbell standing bradford press
  '0106': 'Bizepscurl eng stehend (Langhantel)', // barbell standing close grip curl
  '0107': 'Frontheben bis über Kopf (Langhantel)', // barbell standing front raise over head
  '0108': 'Wadenheben stehend (Langhantel)', // barbell standing leg calf raise
  '0109': 'Trizepsdrücken über Kopf stehend (Langhantel)', // barbell standing overhead triceps extension
  '0110': 'Reverse Curl stehend (Langhantel)', // barbell standing reverse grip curl
  '0111': 'Wadenheben stehend wippend (Langhantel)', // barbell standing rocking leg calf raise
  '0112': 'Rumpfdrehung stehend (Langhantel)', // barbell standing twist
  '0113': 'Bizepscurl breit stehend (Langhantel)', // barbell standing wide-grip curl
  '0114': 'Step-up (Langhantel)', // barbell step-up
  '0115': 'Good Morning mit gestreckten Beinen (Langhantel)', // barbell stiff leg good morning
  '0116': 'Kreuzheben mit gestreckten Beinen (Langhantel)', // barbell straight leg deadlift
  '0117': 'Sumo-Kreuzheben (Langhantel)', // barbell sumo deadlift
  '0118': 'Rudern vorgebeugt Untergriff (Langhantel)', // barbell reverse grip bent over row
  '0119': 'Aufrechtes Rudern (Langhantel, Variante 2)', // barbell upright row v. 2
  '0120': 'Aufrechtes Rudern (Langhantel)', // barbell upright row
  '0121': 'Aufrechtes Rudern (Langhantel, Variante 3)', // barbell upright row v. 3
  '0122': 'Bankdrücken breit (Langhantel)', // barbell wide bench press
  '0123': 'Aufrechtes Rudern breit (Langhantel)', // barbell wide-grip upright row
  '0124': 'Kniebeuge breiter Stand (Langhantel)', // barbell wide squat
  '0125': 'Handgelenkcurl (Langhantel, Variante 2)', // barbell wrist curl v. 2
  '0126': 'Handgelenkcurl (Langhantel)', // barbell wrist curl
  '0127': 'Zercher-Kniebeuge (Langhantel)', // barbell zercher squat
  '0128': 'Battle Ropes', // battling ropes
  '0129': 'Bankdips mit gebeugten Knien', // bench dip (knees bent)
  '0130': 'Hüftstrecken auf der Bank', // bench hip extension
  '0137': 'Body-up (Trizeps)', // body-up
  '0138': 'Bottoms-up (Hüftheben rücklings)', // bottoms-up
  '0139': 'Klimmzug eng im Untergriff (Bizeps)', // biceps narrow pull-ups
  '0140': 'Klimmzug im Untergriff (Bizeps)', // biceps pull-up
  '0148': 'Schulterdrücken abwechselnd (Kabelzug)', // cable alternate shoulder press
  '0149': 'Trizepsstrecken abwechselnd (Kabelzug)', // cable alternate triceps extension
  '0150': 'Latziehen mit Stange (Kabelzug)', // cable bar lateral pulldown
  '0151': 'Bankdrücken (Kabelzug)', // cable bench press
  '0152': 'Trizeps-Konzentrationsstrecken am Knie (Kabelzug)', // cable concentration extension (on knee)
  '0153': 'Latziehen über Kreuz (Kabelzug)', // cable cross-over lateral pulldown
  '0154': 'Reverse Flys über Kreuz (Kabelzug)', // cable cross-over reverse fly
  '0155': 'Crossover (Kabelzug)', // cable cross-over variation
  '0157': 'Kreuzheben (Kabelzug)', // cable deadlift
  '0158': 'Fliegende von oben (Kabelzug)', // cable decline fly
  '0159': 'Rudern breit sitzend auf der Negativbank (Kabelzug)', // cable decline seated wide-grip row
  '0160': 'Rudern breit sitzend am Boden (Kabelzug)', // cable floor seated wide-grip row
  '0161': 'Frontheben nach vorn (Kabelzug)', // cable forward raise
  '0162': 'Frontheben (Kabelzug)', // cable front raise
  '0164': 'Frontheben für die vordere Schulter (Kabelzug)', // cable front shoulder raise
  '0165': 'Hammercurl (Kabelzug, Seil)', // cable hammer curl (with rope)
  '0167': 'Rudern hoch kniend (Kabelzug)', // cable high row (kneeling)
  '0168': 'Adduktion (Kabelzug)', // cable hip adduction
  '0169': 'Schrägbankdrücken (Kabelzug)', // cable incline bench press
  '0170': 'Fliegende auf der Schrägbank auf dem Gymnastikball (Kabelzug)', // cable incline fly (on stability ball)
  '0171': 'Fliegende auf der Schrägbank (Kabelzug)', // cable incline fly
  '0172': 'Latziehen mit gestreckten Armen auf der Schrägbank (Kabelzug)', // cable incline pushdown
  '0173': 'Trizepsstrecken auf der Schrägbank (Kabelzug)', // cable incline triceps extension
  '0174': 'Judo-Wurf / Rumpfrotation (Kabelzug)', // cable judo flip
  '0175': 'Crunch kniend (Kabelzug)', // cable kneeling crunch
  '0176': 'Trizepsstrecken kniend (Kabelzug)', // cable kneeling triceps extension
  '0177': 'Latziehen mit Seil (Kabelzug)', // cable lateral pulldown (with rope attachment)
  '0178': 'Seitheben (Kabelzug)', // cable lateral raise
  '0179': 'Fliegende von unten (Kabelzug)', // cable low fly
  '0180': 'Rudern tief sitzend (Kabelzug)', // cable low seated row
  '0182': 'Bizepscurl eng liegend (Kabelzug)', // cable lying close-grip curl
  '0184': 'Überzüge liegend mit Seil (Kabelzug)', // cable lying extension pullover (with rope attachment)
  '0185': 'Fliegende liegend (Kabelzug)', // cable lying fly
  '0186': 'Trizepsstrecken liegend (Kabelzug)', // cable lying triceps extension
  '0188': 'Fliegende mittig (Kabelzug)', // cable middle fly
  '0189': 'Rudern vorgebeugt einarmig (Kabelzug)', // cable one arm bent over row
  '0190': 'Bizepscurl einarmig (Kabelzug)', // cable one arm curl
  '0191': 'Fliegende vorgebeugt einarmig (Kabelzug)', // cable one arm bent-over fly
  '0192': 'Seitheben einarmig (Kabelzug)', // cable one arm lateral raise
  '0193': 'Rudern hoch einarmig kniend (Kabelzug)', // cable one arm straight back high row (kneeling)
  '0194': 'Trizepsdrücken über Kopf (Kabelzug, Seil)', // cable overhead triceps extension (rope attachment)
  '0195': 'Scottcurl (Kabelzug)', // cable preacher curl
  '0196': 'Pull-Through (Kabelzug, Seil)', // cable pull through (with rope)
  '0197': 'Latziehen mit Pro-Lat-Griff (Kabelzug)', // cable pulldown (pro lat bar)
  '0198': 'Latziehen (Kabelzug, Variante)', // cable pulldown
  '0199': 'Latziehen mit gestreckten Armen stehend (Kabelzug)', // cable straight arm pulldown (standing)
  '0200': 'Trizepsdrücken mit Seil (Kabelzug)', // cable pushdown (with rope attachment)
  '0201': 'Trizepsdrücken (Kabelzug)', // cable pushdown
  '0202': 'Rudern für die hintere Schulter mit Griffen (Kabelzug)', // cable rear delt row (stirrups)
  '0203': 'Face Pull / Rudern zum Gesicht (Kabelzug, Seil)', // cable rear delt row (with rope)
  '0204': 'Trizepsstrecken nach hinten (Kabelzug)', // cable rear drive
  '0205': 'Latziehen hinter dem Nacken (Kabelzug)', // cable rear pulldown
  '0206': 'Reverse Curl (Kabelzug)', // cable reverse curl
  '0207': 'Trizepsdrücken im Untergriff (Kabelzug)', // cable reverse-grip pushdown
  '0208': 'Rudern hoch Untergriff sitzend (Kabelzug)', // cable reverse-grip straight back seated high row
  '0209': 'Scottcurl im Obergriff (Kabelzug)', // cable reverse preacher curl
  '0210': 'Handgelenkcurl Obergriff (Kabelzug)', // cable reverse wrist curl
  '0211': 'Russian Twist auf dem Gymnastikball (Kabelzug)', // cable russian twists (on stability ball)
  '0212': 'Crunch sitzend (Kabelzug)', // cable seated crunch
  '0213': 'Rudern hoch sitzend mit V-Griff (Kabelzug)', // cable seated high row (v-bar)
  '0214': 'Rudern einarmig abwechselnd sitzend (Kabelzug)', // cable seated one arm alternate row
  '0215': 'Reverse Flys sitzend (Kabelzug)', // cable seated rear lateral raise
  '0216': 'Innenrotation Schulter sitzend (Kabelzug)', // cable seated shoulder internal rotation
  '0218': 'Rudern breit sitzend (Kabelzug)', // cable seated wide-grip row
  '0219': 'Schulterdrücken (Kabelzug)', // cable shoulder press
  '0220': 'Schulterheben (Kabelzug)', // cable shrug
  '0221': 'Seitbeuge auf dem Bosu (Kabelzug)', // cable side bend crunch (bosu ball)
  '0222': 'Seitbeuge (Kabelzug)', // cable side bend
  '0223': 'Seitlicher Crunch (Kabelzug)', // cable side crunch
  '0224': 'Handgelenkcurl hinter dem Rücken (Kabelzug)', // cable standing back wrist curl
  '0225': 'Reverse Flys über Kreuz von oben (Kabelzug)', // cable standing cross-over high reverse fly
  '0226': 'Crunch stehend (Kabelzug)', // cable standing crunch
  '0227': 'Fliegende stehend (Kabelzug)', // cable standing fly
  '0228': 'Hüftstrecken stehend (Kabelzug)', // cable standing hip extension
  '0229': 'Bizepscurl nach innen stehend (Kabelzug)', // cable standing inner curl
  '0230': 'Rumpfheben stehend (Kabelzug)', // cable standing lift
  '0231': 'Trizepsstrecken einarmig stehend (Kabelzug)', // cable standing one arm triceps extension
  '0232': 'Latziehen stehend mit Seil (Kabelzug)', // cable standing pulldown (with rope)
  '0233': 'Face Pull stehend (Kabelzug, Seil)', // cable standing rear delt row (with rope)
  '0234': 'Rudern stehend mit V-Griff (Kabelzug)', // cable standing row (v-bar)
  '0235': 'Außenrotation Schulter stehend (Kabelzug)', // cable standing shoulder external rotation
  '0236': 'Rudern mit Rumpfdrehung stehend (Kabelzug)', // cable standing twist row (v-bar)
  '0237': 'Latziehen mit gestreckten Armen (Kabelzug, Seil)', // cable straight arm pulldown (with rope)
  '0238': 'Latziehen mit gestreckten Armen (Kabelzug)', // cable straight arm pulldown
  '0239': 'Rudern sitzend mit geradem Rücken (Kabelzug)', // cable straight back seated row
  '0240': 'Reverse Flys rücklings (Kabelzug)', // cable supine reverse fly
  '0241': 'Trizepsdrücken (Kabelzug, V-Griff)', // cable triceps pushdown (v-bar)
  '0242': 'Reverse Crunch gehockt (Kabelzug)', // cable tuck reverse crunch
  '0243': 'Rumpfdrehung (Kabelzug)', // cable twist
  '0244': 'Zug mit Rumpfdrehung (Kabelzug)', // cable twisting pull
  '0245': 'Latziehen im Untergriff (Kabelzug)', // cable underhand pulldown
  '0246': 'Aufrechtes Rudern (Kabelzug)', // cable upright row
  '0247': 'Handgelenkcurl (Kabelzug)', // cable wrist curl
  '0248': 'Rudern bauchliegend (Cambered Bar)', // cambered bar lying row
  '0251': 'Dips (Brust)', // chest dip
  '0253': 'Klimmzug eng Neutralgriff', // chin-ups (narrow parallel grip)
  '0257': 'Kniekreisen', // circles knee stretch
  '0258': 'Liegestütz im Uhrzeigerkreis', // clock push-up
  '0259': 'Liegestütz eng', // close-grip push-up
  '0260': 'Kokon-Crunch', // cocoons
  '0262': 'Crunch diagonal', // cross body crunch
  '0267': 'Crunch mit Armen über Kopf', // crunch (hands overhead)
  '0271': 'Crunch auf dem Gymnastikball', // crunch (on stability ball)
  '0272': 'Crunch auf dem Gymnastikball mit gestreckten Armen', // crunch (on stability ball, arms straight)
  '0274': 'Crunch', // crunch floor
  '0276': 'Dead Bug', // dead bug
  '0277': 'Crunch auf der Negativbank', // decline crunch
  '0279': 'Liegestütz mit erhöhten Füßen', // decline push-up
  '0282': 'Sit-up auf der Negativbank', // decline sit-up
  '0283': 'Diamant-Liegestütz', // diamond push-up
  '0284': 'Esel-Wadenheben', // donkey calf raise
  '0285': 'Bizepscurl abwechselnd (Kurzhantel)', // dumbbell alternate biceps curl
  '0286': 'Seitdrücken abwechselnd (Kurzhantel)', // dumbbell alternate side press
  '0287': 'Arnold Press (Kurzhantel, Variante 2)', // dumbbell arnold press v. 2
  '0288': 'Überzüge im Halbkreis (Kurzhantel)', // dumbbell around pullover
  '0289': 'Bankdrücken (Kurzhantel)', // dumbbell bench press
  '0290': 'Schulterdrücken sitzend auf der Bank (Kurzhantel)', // dumbbell bench seated press
  '0291': 'Kniebeuge zur Bank (Kurzhantel)', // dumbbell bench squat
  '0292': 'Rudern vorgebeugt einarmig (Kurzhantel)', // dumbbell one arm bent-over row
  '0293': 'Rudern vorgebeugt (Kurzhantel)', // dumbbell bent over row
  '0294': 'Bizepscurl (Kurzhantel)', // dumbbell biceps curl
  '0295': 'Umsetzen (Kurzhantel)', // dumbbell clean
  '0296': 'Bankdrücken eng (Kurzhantel)', // dumbbell close-grip press
  '0297': 'Konzentrationscurl (Kurzhantel)', // dumbbell concentration curl
  '0298': 'Hammercurl diagonal (Kurzhantel)', // dumbbell cross body hammer curl
  '0299': 'Cuban Press (Kurzhantel)', // dumbbell cuban press
  '0300': 'Kreuzheben (Kurzhantel)', // dumbbell deadlift
  '0301': 'Negativbankdrücken (Kurzhantel)', // dumbbell decline bench press
  '0302': 'Fliegende auf der Negativbank (Kurzhantel)', // dumbbell decline fly
  '0303': 'Negativbankdrücken Neutralgriff (Kurzhantel)', // dumbbell decline hammer press
  '0304': 'Schulterheben auf der Negativbank (Kurzhantel, Variante 2)', // dumbbell decline shrug v. 2
  '0305': 'Schulterheben auf der Negativbank (Kurzhantel)', // dumbbell decline shrug
  '0306': 'Trizepsstrecken auf der Negativbank (Kurzhantel)', // dumbbell decline triceps extension
  '0307': 'Fliegende mit Drehung auf der Negativbank (Kurzhantel)', // dumbbell decline twist fly
  '0308': 'Fliegende (Kurzhantel)', // dumbbell fly
  '0309': 'Frontheben (Kurzhantel, Variante 2)', // dumbbell front raise v. 2
  '0310': 'Frontheben (Kurzhantel)', // dumbbell front raise
  '0311': 'Seitheben Daumen oben (Kurzhantel)', // dumbbell full can lateral raise
  '0312': 'Hammercurl (Kurzhantel, Variante 2)', // dumbbell hammer curl v. 2
  '0313': 'Hammercurl (Kurzhantel)', // dumbbell hammer curl
  '0314': 'Schrägbankdrücken (Kurzhantel)', // dumbbell incline bench press
  '0315': 'Bizepscurl auf der Schrägbank (Kurzhantel)', // dumbbell incline biceps curl
  '0316': 'Fliegende auf der Schrägbank mit Drehung (Kurzhantel)', // dumbbell incline twisting fly
  '0317': 'Schrägbank-Curl (Kurzhantel, Variante 2)', // dumbbell incline curl v. 2
  '0318': 'Schrägbank-Curl (Kurzhantel)', // dumbbell incline curl
  '0319': 'Fliegende auf der Schrägbank (Kurzhantel)', // dumbbell incline fly
  '0320': 'Hammercurl auf der Schrägbank (Kurzhantel)', // dumbbell incline hammer curl
  '0321': 'Schrägbankdrücken Neutralgriff (Kurzhantel)', // dumbbell incline hammer press
  '0322': 'Bizepscurl nach außen auf der Schrägbank (Kurzhantel)', // dumbbell incline inner biceps curl
  '0323': 'Seitheben einarmig auf der Schrägbank (Kurzhantel)', // dumbbell incline one arm lateral raise
  '0324': 'Schrägbankdrücken Hammergriff (Kurzhantel)', // dumbbell incline palm-in press
  '0325': 'Frontheben auf der Schrägbank (Kurzhantel)', // dumbbell incline raise
  '0326': 'Reverse Flys bauchliegend auf der Schrägbank (Kurzhantel)', // dumbbell incline rear lateral raise
  '0327': 'Rudern bauchliegend auf der Schrägbank (Kurzhantel)', // dumbbell incline row
  '0328': 'Schulter-Protraktion auf der Schrägbank (Kurzhantel)', // dumbbell incline shoulder raise
  '0329': 'Schulterheben auf der Schrägbank (Kurzhantel)', // dumbbell incline shrug
  '0330': 'Trizepsstrecken auf der Schrägbank (Kurzhantel)', // dumbbell incline triceps extension
  '0331': 'Fliegende auf der Schrägbank mit Eindrehen (Kurzhantel)', // dumbbell incline twisted flyes
  '0332': 'Iron Cross (Kurzhantel)', // dumbbell iron cross
  '0333': 'Trizeps-Kickback (Kurzhantel)', // dumbbell kickback
  '0334': 'Seitheben (Kurzhantel)', // dumbbell lateral raise
  '0335': 'Seitheben zum Frontheben (Kurzhantel)', // dumbbell lateral to front raise
  '0336': 'Ausfallschritt (Kurzhantel)', // dumbbell lunge
  '0337': 'Trizepsstrecken liegend über das Gesicht (Kurzhantel)', // dumbbell lying extension (across face)
  '0338': 'Trizepsstrecken liegend Neutralgriff (Kurzhantel)', // dumbbell lying elbow press
  '0339': 'Beinbeuger liegend (Kurzhantel)', // dumbbell lying leg curl
  '0340': 'Bankdrücken Hammergriff (Kurzhantel)', // dumbbell lying hammer press
  '0341': 'Reverse Flys einarmig seitlich liegend (Kurzhantel)', // dumbbell lying one arm deltoid rear
  '0342': 'Bankdrücken einarmig (Kurzhantel, Variante 2)', // dumbbell lying one arm press v. 2
  '0343': 'Bankdrücken einarmig (Kurzhantel)', // dumbbell lying one arm press
  '0344': 'Trizepsstrecken einarmig liegend Obergriff (Kurzhantel)', // dumbbell lying one arm pronated triceps extension
  '0345': 'Reverse Flys einarmig bauchliegend (Kurzhantel)', // dumbbell lying one arm rear lateral raise
  '0346': 'Trizepsstrecken einarmig liegend Untergriff (Kurzhantel)', // dumbbell lying one arm supinated triceps extension
  '0347': 'Pronation liegend (Kurzhantel)', // dumbbell lying pronation
  '0348': 'Reverse Flys bauchliegend (Kurzhantel)', // dumbbell lying rear lateral raise
  '0349': 'Supination liegend (Kurzhantel)', // dumbbell lying supination
  '0350': 'Bizepscurl rücklings auf der Bank (Kurzhantel)', // dumbbell lying supine curl
  '0351': 'Trizepsstrecken liegend (Kurzhantel)', // dumbbell lying triceps extension
  '0352': 'Bankdrücken Neutralgriff (Kurzhantel)', // dumbbell neutral grip bench press
  '0353': 'Konzentrationscurl einarmig auf dem Gymnastikball (Kurzhantel)', // dumbbell one arm concentration curl (on stability ball)
  '0354': 'Trizeps-Kickback einarmig (Kurzhantel)', // dumbbell one arm kickback
  '0355': 'Seitheben einarmig (Kurzhantel)', // dumbbell one arm lateral raise
  '0356': 'Seitheben einarmig mit Abstützen (Kurzhantel)', // dumbbell one arm lateral raise with support
  '0358': 'Handgelenkcurl Obergriff einarmig (Kurzhantel)', // dumbbell one arm reverse wrist curl
  '0359': 'Reverse Flys einarmig mit Abstützen (Kurzhantel)', // dumbbell one arm reverse fly (with support)
  '0360': 'Schulterdrücken einarmig (Kurzhantel, Variante 2)', // dumbbell one arm shoulder press v. 2
  '0361': 'Schulterdrücken einarmig (Kurzhantel)', // dumbbell one arm shoulder press
  '0362': 'Trizepsstrecken einarmig auf der Bank (Kurzhantel)', // dumbbell one arm triceps extension (on bench)
  '0363': 'Aufrechtes Rudern einarmig (Kurzhantel)', // dumbbell one arm upright row
  '0364': 'Handgelenkcurl einarmig (Kurzhantel)', // dumbbell one arm wrist curl
  '0365': 'Handgelenkcurl Neutralgriff über der Bank (Kurzhantel)', // dumbbell over bench neutral wrist curl
  '0366': 'Handgelenkcurl Neutralgriff einarmig über der Bank (Kurzhantel)', // dumbbell over bench one arm neutral wrist curl
  '0367': 'Handgelenkcurl einarmig über der Bank (Kurzhantel)', // dumbbell over bench one arm wrist curl
  '0368': 'Handgelenkcurl Obergriff über der Bank (Kurzhantel)', // dumbbell over bench reverse wrist curl
  '0369': 'Handgelenkcurl über der Bank (Kurzhantel)', // dumbbell over bench wrist curl
  '0370': 'Hammer-Scottcurl (Kurzhantel)', // dumbbell preacher hammer curl
  '0371': 'Sprungkniebeuge (Kurzhantel)', // dumbbell plyo squat
  '0372': 'Scottcurl (Kurzhantel)', // dumbbell preacher curl
  '0373': 'Trizepsstrecken Obergriff (Kurzhantel)', // dumbbell pronate-grip triceps extension
  '0374': 'Curl bauchliegend auf der Schrägbank (Kurzhantel)', // dumbbell prone incline curl
  '0375': 'Überzüge (Kurzhantel)', // dumbbell pullover
  '0376': 'Seitheben (Kurzhantel, Variante)', // dumbbell raise
  '0377': 'Rudern für die hintere Schulter (Kurzhantel)', // dumbbell rear delt row
  '0378': 'Reverse Flys (Kurzhantel)', // dumbbell rear fly
  '0379': 'Reverse Flys mit Kopfauflage (Kurzhantel)', // dumbbell rear lateral raise (support head)
  '0380': 'Reverse Flys vorgebeugt (Kurzhantel)', // dumbbell rear lateral raise
  '0381': 'Ausfallschritt rückwärts (Kurzhantel)', // dumbbell rear lunge
  '0382': 'Reverse Curl / Curl im Obergriff (Kurzhantel)', // dumbbell reverse grip biceps curl
  '0383': 'Reverse Flys stehend (Kurzhantel)', // dumbbell reverse fly
  '0384': 'Scottcurl im Obergriff (Kurzhantel)', // dumbbell reverse preacher curl
  '0385': 'Handgelenkcurl Obergriff (Kurzhantel)', // dumbbell reverse wrist curl
  '0386': 'Reverse Flys mit Rotation (Kurzhantel)', // dumbbell rotation reverse fly
  '0387': 'Frontheben abwechselnd sitzend (Kurzhantel)', // dumbbell seated alternate front raise
  '0388': 'Schulterdrücken abwechselnd sitzend (Kurzhantel)', // dumbbell seated alternate press
  '0389': 'Trizepsstrecken über Kopf sitzend auf der Bank (Kurzhantel)', // dumbbell seated bench extension
  '0390': 'Bizepscurl sitzend auf dem Gymnastikball (Kurzhantel)', // dumbbell seated biceps curl (on stability ball)
  '0391': 'Bizepscurl sitzend (Kurzhantel)', // dumbbell seated curl
  '0392': 'Frontheben sitzend (Kurzhantel)', // dumbbell seated front raise
  '0393': 'Bizepscurl nach außen sitzend (Kurzhantel)', // dumbbell seated inner biceps curl
  '0394': 'Trizeps-Kickback sitzend (Kurzhantel)', // dumbbell seated kickback
  '0395': 'Seitheben sitzend (Kurzhantel, Variante 2)', // dumbbell seated lateral raise v. 2
  '0396': 'Seitheben sitzend (Kurzhantel)', // dumbbell seated lateral raise
  '0397': 'Handgelenkcurl Neutralgriff sitzend (Kurzhantel)', // dumbbell seated neutral wrist curl
  '0398': 'Trizeps-Kickback einarmig sitzend (Kurzhantel)', // dumbbell seated one arm kickback
  '0399': 'Unterarmrotation einarmig sitzend (Kurzhantel)', // dumbbell seated one arm rotate
  '0400': 'Wadenheben einbeinig sitzend (Kurzhantel)', // dumbbell seated one leg calf raise
  '0401': 'Handgelenkcurl Untergriff sitzend (Kurzhantel)', // dumbbell seated palms up wrist curl
  '0402': 'Scottcurl sitzend (Kurzhantel)', // dumbbell seated preacher curl
  '0403': 'Konzentrationscurl im Obergriff sitzend (Kurzhantel)', // dumbbell seated reverse grip concentration curl
  '0404': 'Schulterdrücken Neutralgriff sitzend (Kurzhantel)', // dumbbell seated shoulder press (parallel grip)
  '0405': 'Schulterdrücken sitzend (Kurzhantel)', // dumbbell seated shoulder press
  '0406': 'Schulterheben (Kurzhantel)', // dumbbell shrug
  '0407': 'Seitbeuge (Kurzhantel)', // dumbbell side bend
  '0408': 'Seitheben einarmig seitlich liegend (Kurzhantel)', // dumbbell side lying one hand raise
  '0409': 'Wadenheben einbeinig (Kurzhantel)', // dumbbell single leg calf raise
  '0410': 'Bulgarische Kniebeuge (Kurzhantel)', // dumbbell single leg split squat
  '0411': 'Kniebeuge einbeinig (Kurzhantel)', // dumbbell single leg squat
  '0413': 'Kniebeuge (Kurzhantel)', // dumbbell squat
  '0414': 'Schulterdrücken abwechselnd stehend (Kurzhantel)', // dumbbell standing alternate overhead press
  '0415': 'Frontheben abwechselnd stehend (Kurzhantel)', // dumbbell standing alternate raise
  '0416': 'Bizepscurl stehend (Kurzhantel)', // dumbbell standing biceps curl
  '0417': 'Wadenheben stehend (Kurzhantel)', // dumbbell standing calf raise
  '0418': 'Konzentrationscurl stehend (Kurzhantel)', // dumbbell standing concentration curl
  '0419': 'Frontheben bis über Kopf stehend (Kurzhantel)', // dumbbell standing front raise above head
  '0420': 'Trizeps-Kickback stehend (Kurzhantel)', // dumbbell standing kickback
  '0421': 'Konzentrationscurl einarmig stehend (Kurzhantel)', // dumbbell standing one arm concentration curl
  '0422': 'Bizepscurl einarmig über die Schrägbank (Kurzhantel)', // dumbbell standing one arm curl (over incline bench)
  '0423': 'Trizepsstrecken über Kopf einarmig stehend (Kurzhantel)', // dumbbell standing one arm extension
  '0424': 'Schulterdrücken einarmig Neutralgriff stehend (Kurzhantel)', // dumbbell standing one arm palm in press
  '0425': 'Reverse Curl einarmig stehend (Kurzhantel)', // dumbbell standing one arm reverse curl
  '0426': 'Schulterdrücken stehend (Kurzhantel)', // dumbbell standing overhead press
  '0427': 'Schulterdrücken Neutralgriff stehend (Kurzhantel)', // dumbbell standing palms in press
  '0428': 'Scottcurl stehend (Kurzhantel)', // dumbbell standing preacher curl
  '0429': 'Reverse Curl stehend (Kurzhantel)', // dumbbell standing reverse curl
  '0430': 'Trizepsstrecken über Kopf stehend (Kurzhantel)', // dumbbell standing triceps extension
  '0431': 'Step-up (Kurzhantel)', // dumbbell step-up
  '0432': 'Kreuzheben mit gestreckten Beinen (Kurzhantel)', // dumbbell stiff leg deadlift
  '0433': 'Überzüge mit gestreckten Armen (Kurzhantel)', // dumbbell straight arm pullover
  '0434': 'Kreuzheben mit durchgestreckten Beinen (Kurzhantel)', // dumbbell straight leg deadlift
  '0436': 'Tate Press (Kurzhantel)', // dumbbell tate press
  '0437': 'Aufrechtes Rudern (Kurzhantel)', // dumbbell upright row
  '0438': 'W-Press (Kurzhantel)', // dumbbell w-press
  '0439': 'Zottman Curl (Kurzhantel)', // dumbbell zottman curl
  '0443': 'Ellbogen-zum-Knie-Crunch', // elbow-to-knee
  '0445': 'Schulterdrücken liegend auf der Schrägbank (SZ-Stange)', // ez barbell anti-gravity press
  '0446': 'Bizepscurl eng (SZ-Stange)', // ez barbell close-grip curl
  '0447': 'Bizepscurl (SZ-Stange)', // ez barbell curl
  '0448': 'Negativbankdrücken eng zum Gesicht (SZ-Stange)', // ez barbell decline close grip face press
  '0449': 'Trizepsstrecken auf der Schrägbank (SZ-Stange)', // ez barbell incline triceps extension
  '0450': 'JM Press (SZ-Stange)', // ez barbell jm bench press
  '0451': 'Reverse Curl (SZ-Stange)', // ez barbell reverse grip curl
  '0452': 'Scottcurl im Obergriff (SZ-Stange)', // ez barbell reverse grip preacher curl
  '0453': 'Trizepsdrücken über Kopf sitzend (SZ-Stange)', // ez barbell seated triceps extension
  '0454': 'Spider Curl (SZ-Stange)', // ez barbell spider curl
  '0455': 'Fingercurl (Langhantel)', // finger curls
  '0456': 'Sit-up mit gebeugten Knien', // flexion leg sit up (bent knee)
  '0457': 'Sit-up mit gestreckten Armen', // flexion leg sit up (straight arm)
  '0458': 'Fliegende am Boden (Langhantel)', // floor fly (with barbell)
  '0459': 'Flutter Kicks / Beinschlag', // flutter kicks
  '0464': 'Unterarmstütz mit Drehung', // front plank with twist
  '0466': 'Gironda-Klimmzug zum Brustbein', // gironda sternum chin
  '0467': 'Gorilla-Klimmzug mit Knieheben', // gorilla chin
  '0469': 'Leisten-Crunch', // groin crunch
  '0471': 'Handstand-Liegestütz', // handstand push-up
  '0472': 'Beinheben hängend', // hanging leg raise
  '0473': 'Pike hängend (Beine zur Stange)', // hanging pike
  '0474': 'Hüftheben hängend mit gestreckten Beinen', // hanging straight leg hip raise
  '0475': 'Beinheben hängend mit gestreckten Beinen', // hanging straight leg raise
  '0476': 'Hüftheben hängend mit gestreckten Beinen und Drehung', // hanging straight twisting leg hip raise
  '0484': 'Hüftheben rücklings mit gebeugten Knien', // hip raise (bent knee)
  '0488': 'Rückenstrecken auf der Bank', // hyperextension (on bench)
  '0489': 'Rückenstrecken / Hyperextensions', // hyperextension
  '0490': 'Liegestütz eng erhöht (Hände auf Bank)', // incline close-grip push-up
  '0491': 'Beinheben auf der Schrägbank mit gestreckten Beinen', // incline leg hip raise (leg straight)
  '0492': 'Liegestütz erhöht mit Tiefsprung', // incline push up depth jump
  '0493': 'Liegestütz erhöht (Hände auf Bank)', // incline push-up
  '0494': 'Liegestütz erhöht im Untergriff', // incline reverse grip push-up
  '0495': 'Sit-up mit Drehung auf der Schrägbank', // incline twisting sit-up
  '0496': 'Nordic Curl (an der Bank)', // nordic hamstring curl (bench support)
  '0497': 'Rudern am Körpergewicht (Variante 2)', // inverted row v. 2
  '0498': 'Rudern am Körpergewicht mit Schlaufen', // inverted row with straps
  '0499': 'Rudern am Körpergewicht', // inverted row
  '0500': 'Scheibenwischer isometrisch', // isometric wipers
  '0501': 'Jumping-Jack-Burpee', // jack burpee
  '0507': 'Klappmesser-Sit-up', // jackknife sit-up
  '0508': 'Janda-Sit-up', // janda sit-up
  '0513': 'Sprungkniebeuge (Variante 2)', // jump squat v. 2
  '0514': 'Sprungkniebeuge', // jump squat
  '0517': 'Windmühle fortgeschritten (Kettlebell)', // kettlebell advanced windmill
  '0518': 'Hang Clean abwechselnd (Kettlebell)', // kettlebell alternating hang clean
  '0519': 'Bodendrücken abwechselnd (Kettlebell)', // kettlebell alternating press on floor
  '0520': 'Schulterdrücken abwechselnd (Kettlebell)', // kettlebell alternating press
  '0521': 'Renegade Row abwechselnd (Kettlebell)', // kettlebell alternating renegade row
  '0522': 'Rudern abwechselnd (Kettlebell)', // kettlebell alternating row
  '0523': 'Arnold Press (Kettlebell)', // kettlebell arnold press
  '0524': 'Bent Press (Kettlebell)', // kettlebell bent press
  '0525': 'Bottoms-up Clean aus dem Hang (Kettlebell)', // kettlebell bottoms up clean from the hang position
  '0526': 'Hang Clean abwechselnd mit zwei Kettlebells', // kettlebell double alternating hang clean
  '0527': 'Stoßen mit zwei Kettlebells', // kettlebell double jerk
  '0528': 'Push Press mit zwei Kettlebells', // kettlebell double push press
  '0529': 'Reißen mit zwei Kettlebells', // kettlebell double snatch
  '0530': 'Windmühle mit zwei Kettlebells', // kettlebell double windmill
  '0531': 'Bodendrücken einarmig mit großer Bewegung (Kettlebell)', // kettlebell extended range one arm press on floor
  '0532': 'Achter durch die Beine (Kettlebell)', // kettlebell figure 8
  '0533': 'Frontkniebeuge (Kettlebell)', // kettlebell front squat
  '0534': 'Goblet Squat (Kettlebell)', // kettlebell goblet squat
  '0535': 'Hang Clean (Kettlebell)', // kettlebell hang clean
  '0536': 'Ausfallschritt mit Durchreichen (Kettlebell)', // kettlebell lunge pass through
  '0537': 'Umsetzen und Stoßen einarmig (Kettlebell)', // kettlebell one arm clean and jerk
  '0538': 'Stoßen einarmig (Kettlebell)', // kettlebell one arm jerk
  '0539': 'Schulterdrücken einarmig zur Seite (Kettlebell)', // kettlebell one arm military press to the side
  '0540': 'Push Press einarmig (Kettlebell)', // kettlebell one arm push press
  '0541': 'Rudern einarmig (Kettlebell)', // kettlebell one arm row
  '0542': 'Reißen einarmig (Kettlebell)', // kettlebell one arm snatch
  '0543': 'Pirate Ships (Kettlebell)', // kettlebell pirate ships
  '0544': 'Pistol Squat (Kettlebell)', // kettlebell pistol squat
  '0545': 'Plyo-Liegestütz (Kettlebell)', // kettlebell plyo push-up
  '0546': 'Schulterdrücken sitzend (Kettlebell)', // kettlebell seated press
  '0547': 'Seesaw Press (Kettlebell)', // kettlebell seesaw press
  '0548': 'Sumo-Hochziehen (Kettlebell)', // kettlebell sumo high pull
  '0549': 'Kettlebell Swing', // kettlebell swing
  '0550': 'Thruster (Kettlebell)', // kettlebell thruster
  '0551': 'Turkish Get-up mit Kniebeuge (Kettlebell)', // kettlebell turkish get up (squat style)
  '0552': 'Umsetzen beidarmig (Kettlebell)', // kettlebell two arm clean
  '0553': 'Schulterdrücken beidarmig (Kettlebell)', // kettlebell two arm military press
  '0554': 'Windmühle (Kettlebell)', // kettlebell windmill
  '0555': 'Beinstrecken sitzend (Kick-out)', // kick out sit
  '0558': 'Muscle-up mit Schwung (Kipping)', // kipping muscle up
  '0562': 'Landmine 180 / Rotation (Langhantel)', // landmine 180
  '0570': 'Knieanziehen auf der Flachbank', // leg pull in flat bench
  '0571': 'Rudern eng abwechselnd sitzend (Maschine)', // lever alternating narrow grip seated row
  '0572': 'Klimmzug im Untergriff unterstützt (Maschine)', // lever assisted chin-up
  '0573': 'Rückenstrecker (Maschine)', // lever back extension
  '0574': 'Landmine-Rudern vorgebeugt (Langhantel)', // landmine bent over row
  '0575': 'Bizepscurl (Maschine)', // lever bicep curl
  '0576': 'Brustpresse (Maschine, Variante)', // lever chest press
  '0577': 'Brustpresse (Maschine)', // lever chest press
  '0578': 'Kreuzheben (Maschine)', // lever deadlift
  '0579': 'Latziehen (Maschine)', // lever front pulldown
  '0580': 'Schulterheben ohne Griff (Maschine)', // lever gripless shrug
  '0581': 'Hohes Rudern (Maschine)', // lever high row
  '0582': 'Beinbeuger kniend (Maschine)', // lever kneeling leg curl
  '0583': 'Rumpfdrehung kniend (Maschine)', // lever kneeling twist
  '0584': 'Seitheben (Maschine)', // lever lateral raise
  '0585': 'Beinstrecker (Maschine)', // lever leg extension
  '0586': 'Beinbeuger liegend (Maschine)', // lever lying leg curl
  '0587': 'Schulterdrücken frontal (Maschine)', // lever military press
  '0588': 'Rudern eng sitzend (Maschine)', // lever narrow grip seated row
  '0589': 'Landmine-Rudern einarmig (Langhantel)', // landmine one arm row
  '0590': 'Schulterdrücken einarmig (Maschine)', // lever one arm shoulder press
  '0591': 'Dips Obergriff (Maschine)', // lever overhand triceps dip
  '0592': 'Scottcurl (Maschine)', // lever preacher curl
  '0593': 'Reverse Hyperextension (Maschine)', // lever reverse hyperextension
  '0594': 'Wadenheben sitzend (Maschine)', // lever seated calf raise
  '0595': 'Crunch sitzend mit Brustpolster (Maschine)', // lever seated crunch (chest pad)
  '0596': 'Butterfly (Maschine)', // lever seated fly
  '0597': 'Abduktoren (Maschine)', // lever seated hip abduction
  '0598': 'Adduktoren (Maschine)', // lever seated hip adduction
  '0599': 'Beinbeuger sitzend (Maschine)', // lever seated leg curl
  '0600': 'Beinheben-Crunch sitzend (Maschine)', // lever seated leg raise crunch
  '0601': 'Reverse Butterfly Neutralgriff (Maschine)', // lever seated reverse fly (parallel grip)
  '0602': 'Reverse Butterfly (Maschine)', // lever seated reverse fly
  '0603': 'Schulterdrücken (Maschine)', // lever shoulder press
  '0604': 'Schulterheben (Maschine)', // lever shrug
  '0605': 'Wadenheben stehend (Maschine)', // lever standing calf raise
  '0606': 'T-Bar-Rudern (Maschine)', // lever t bar row
  '0607': 'Trizepsstrecken (Maschine)', // lever triceps extension
  '0609': 'London Bridge (Seil)', // london bridge
  '0613': 'Quadrizeps-Dehnung seitlich liegend', // side lying quad stretch
  '0620': 'Beinheben liegend auf der Flachbank', // lying leg raise flat bench
  '0624': 'Wandsitz mit Marschieren', // wall sit march
  '0627': 'Klimmzug Kreuzgriff', // mixed grip chin-up
  '0628': 'Monster Walk', // monster walk
  '0630': 'Bergsteiger (Mountain Climber)', // mountain climber
  '0631': 'Muscle-up', // muscle up
  '0634': 'Negativ-Crunch', // negative crunch
  '0635': 'Seitlicher Crunch am Boden', // oblique crunches floor
  '0636': 'Hammercurl (Langhantel)', // olympic barbell hammer curl
  '0637': 'Trizepsstrecken (Langhantel)', // olympic barbell triceps extension
  '0638': 'Klimmzug einarmig im Untergriff', // one arm chin-up
  '0639': 'Dips einarmig', // one arm dip
  '0640': 'Ball Slam einarmig (Medizinball)', // one arm slam (with medicine ball)
  '0641': 'Otis-up (Sit-up mit Hantelscheibe)', // otis up
  '0642': 'Liegestütz mit Beinkick nach außen', // outside leg kick push-up
  '0643': 'Trizeps-Dehnung über Kopf', // overhead triceps stretch
  '0648': 'Power Clean (Langhantel)', // power clean
  '0650': 'Knieanziehen auf dem Gymnastikball', // pull-in (on stability ball)
  '0651': 'Klimmzug Neutralgriff', // pull up (neutral grip)
  '0652': 'Klimmzug', // pull-up
  '0653': 'Liegestütz auf dem Bosu', // push-up (bosu ball)
  '0655': 'Liegestütz auf dem Gymnastikball', // push-up (on stability ball)
  '0656': 'Liegestütz auf dem Gymnastikball (Variante 2)', // push-up (on stability ball)
  '0658': 'Liegestütz an der Wand (Variante 2)', // push-up (wall) v. 2
  '0659': 'Liegestütz an der Wand', // push-up (wall)
  '0660': 'Liegestütz eng auf Kurzhanteln', // push-up close-grip off dumbbell
  '0661': 'Liegestütz mit Beinkick nach innen', // push-up inside leg kick
  '0662': 'Liegestütz', // push-up
  '0663': 'Liegestütz auf dem Medizinball', // push-up medicine ball
  '0664': 'Liegestütz mit Seitstütz', // push-up to side plank
  '0666': 'Liegestütz mit Armheben', // raise single arm push-up
  '0668': 'Brücke rücklings von der Negativbank', // rear decline bridge
  '0669': 'Dehnung hintere Schulter', // rear deltoid stretch
  '0670': 'Klimmzug hinter dem Nacken', // rear pull-up
  '0672': 'Dips rücklings', // reverse dip
  '0673': 'Latziehen im Untergriff (Maschine)', // reverse grip machine lat pulldown
  '0674': 'Klimmzug im Untergriff', // reverse grip pull-up
  '0675': 'Reverse Hyperextension auf dem Gymnastikball', // reverse hyper extension (on stability ball)
  '0677': 'Ring-Dips', // ring dips
  '0678': 'Rocky-Klimmzug (vorn und hinter dem Nacken)', // rocky pull-up pulldown
  '0680': 'Seilklettern', // rope climb
  '0684': 'Laufen auf der Stelle (mit Gerät)', // run (equipment)
  '0685': 'Laufen auf der Stelle', // run
  '0687': 'Russian Twist', // russian twist
  '0688': 'Schulterblatt-Klimmzug', // scapular pull-up
  '0689': 'Beinheben sitzend', // seated leg raise
  '0690': 'Dehnung unterer Rücken sitzend', // seated lower back stretch
  '0691': 'Seitlicher Crunch sitzend an der Wand', // seated side crunch (wall)
  '0696': 'Nordic Curl am Boden', // nordic hamstring curl (on floor)
  '0697': 'Nordic Curl', // nordic hamstring curl
  '0699': 'Liegestütz mit Schultertippen', // shoulder tap push-up
  '0705': 'Seitstütz', // side bridge
  '0709': 'Seitliches Hüftheben am Barren', // side hip (on parallel bars)
  '0710': 'Seitliches Beinheben (Abduktion)', // side hip abduction
  '0716': 'Nackendehnung mit seitlichem Druck', // side push neck stretch
  '0717': 'Liegestütz seitlich (Trizeps)', // side push-up
  '0720': 'Klimmzug seitlich wechselnd', // side-to-side chin
  '0721': 'Handgelenk-Dehnung seitlich', // side wrist pull stretch
  '0725': 'Liegestütz einarmig', // single arm push-up
  '0727': 'Wadenheben einbeinig auf einer Kurzhantel', // single leg calf raise (on a dumbbell)
  '0730': 'Beinbeuger einbeinig mit Gleitpad', // single leg platform slide
  '0735': 'Sit-up (Variante 2)', // sit-up v. 2
  '0738': 'Wadendrücken an der Beinpresse 45° (Maschine)', // sled 45° calf press
  '0739': 'Beinpresse 45° (Maschine)', // sled 45° leg press
  '0740': 'Beinpresse 45° breit (Maschine)', // sled 45° leg wide press
  '0741': 'Hackenschmidt-Kniebeuge enger Stand (Maschine)', // sled closer hack squat
  '0742': 'Wadenheben schräg (Maschine)', // sled forward angled calf raise
  '0743': 'Hackenschmidt-Kniebeuge (Maschine)', // sled hack squat
  '0744': 'Kniebeuge liegend (Maschine)', // sled lying squat
  '0746': 'Schulterheben hinter dem Rücken (Multipresse)', // smith back shrug
  '0747': 'Nackendrücken (Multipresse)', // smith behind neck press
  '0748': 'Bankdrücken (Multipresse)', // smith bench press
  '0749': 'Good Morning mit gebeugten Knien (Multipresse)', // smith bent knee good morning
  '0750': 'Kniebeuge zum Stuhl (Multipresse)', // smith chair squat
  '0751': 'Bankdrücken eng (Multipresse)', // smith close-grip bench press
  '0752': 'Kreuzheben (Multipresse)', // smith deadlift
  '0753': 'Negativbankdrücken (Multipresse)', // smith decline bench press
  '0754': 'Negativbankdrücken Untergriff (Multipresse)', // smith decline reverse-grip bench press
  '0755': 'Hackenschmidt-Kniebeuge (Multipresse)', // smith hack squat
  '0756': 'Hüftheben (Multipresse)', // smith hip raise
  '0757': 'Schrägbankdrücken (Multipresse)', // smith incline bench press
  '0758': 'Schrägbankdrücken Untergriff (Multipresse)', // smith incline reverse-grip bench press
  '0759': 'Schulter-Protraktion auf der Schrägbank (Multipresse)', // smith incline shoulder raises
  '0760': 'Beinpresse (Multipresse)', // smith leg press
  '0761': 'Rudern eng (Multipresse)', // smith narrow row
  '0762': 'Rudern für die hintere Schulter (Multipresse)', // smith rear delt row
  '0763': 'Wadenheben umgekehrt / Zehenheben (Multipresse)', // smith reverse calf raises
  '0764': 'Bankdrücken Untergriff (Multipresse)', // smith reverse-grip bench press
  '0765': 'Schulterdrücken sitzend (Multipresse)', // smith seated shoulder press
  '0766': 'Schulterdrücken (Multipresse)', // smith shoulder press
  '0767': 'Schulterheben (Multipresse)', // smith shrug
  '0768': 'Bulgarische Kniebeuge (Multipresse)', // smith single leg split squat
  '0769': 'Ausfallschritt explosiv (Multipresse)', // smith sprint lunge
  '0770': 'Kniebeuge (Multipresse)', // smith squat
  '0771': 'Handgelenkcurl hinter dem Rücken (Multipresse)', // smith standing back wrist curl
  '0772': 'Nackendrücken stehend (Multipresse)', // smith standing behind head military press
  '0773': 'Wadenheben stehend (Multipresse)', // smith standing leg calf raise
  '0774': 'Schulterdrücken stehend (Multipresse)', // smith standing military press
  '0775': 'Aufrechtes Rudern (Multipresse)', // smith upright row
  '0776': 'Snatch Pull / Zug zum Reißen (Langhantel)', // snatch pull
  '0777': 'Spell Caster (Kurzhantel)', // spell caster
  '0778': 'Spiderman-Liegestütz', // spider crawl push up
  '0786': 'Squat Jerk / Ausstoßen in die Hocke (Langhantel)', // squat jerk
  '0788': 'Nackendrücken stehend (Langhantel)', // standing behind neck press
  '0794': 'Seitliche Dehnung stehend', // standing lateral stretch
  '0795': 'Beinbeuger einbeinig stehend', // standing single leg curl
  '0796': 'Rollout stehend (Bauchroller)', // standing ab wheel rollout
  '0798': 'Fahrradergometer', // stationary bike walk
  '0803': 'Superman-Liegestütz', // superman push-up
  '0805': 'Fallout im Schlingentrainer', // suspended abdominal fallout
  '0806': 'Liegestütz im Schlingentrainer', // suspended push-up
  '0807': 'Reverse Crunch im Schlingentrainer', // suspended reverse crunch
  '0808': 'Rudern im Schlingentrainer', // suspended row
  '0809': 'Split Squat im Schlingentrainer', // suspended split squat
  '0811': 'Kreuzheben (Trap Bar)', // trap bar deadlift
  '0812': 'Bankdips mit Füßen auf der Bank', // triceps dip (bench leg)
  '0813': 'Dips zwischen zwei Bänken', // triceps dip (between benches)
  '0814': 'Dips (Trizeps)', // triceps dip
  '0815': 'Dips am Boden (rücklings)', // triceps dips floor
  '0816': 'Trizepsdrücken am Körpergewicht', // triceps press
  '0817': 'Trizeps-Dehnung', // triceps stretch
  '0818': 'Latziehen Neutralgriff mit Doppelgriff (Kabelzug)', // twin handle parallel grip lat pulldown
  '0826': 'Beinheben senkrecht am Barren', // vertical leg raise (on parallel bars)
  '0830': 'Bankdips mit Gewicht', // weighted bench dip
  '0832': 'Crunch mit Gewicht', // weighted crunch
  '0833': 'Esel-Wadenheben mit Gewicht', // weighted donkey calf raise
  '0834': 'Frontheben mit Hantelscheibe', // weighted front raise
  '0835': 'Rückenstrecken mit Gewicht auf dem Gymnastikball', // weighted hyperextension (on stability ball)
  '0840': 'Crunch mit Gewicht über Kopf auf dem Gymnastikball', // weighted overhead crunch (on stability ball)
  '0841': 'Klimmzug mit Zusatzgewicht', // weighted pull-up
  '0844': 'Armkreisen mit Gewicht', // weighted round arm
  '0845': 'Russian Twist mit Gewicht und angehobenen Beinen', // weighted russian twist (legs up)
  '0846': 'Russian Twist mit Gewicht', // weighted russian twist
  '0847': 'Bizepscurl sitzend auf dem Gymnastikball (Medizinball)', // weighted seated bicep curl (on stability ball)
  '0849': 'Rumpfdrehung mit Gewicht auf dem Gymnastikball', // weighted seated twist (on stability ball)
  '0850': 'Seitbeuge mit Gewicht auf dem Gymnastikball', // weighted side bend (on stability ball)
  '0851': 'Sissy Squat mit Gewicht', // weighted sissy squat
  '0852': 'Kniebeuge mit Gewicht', // weighted squat
  '0853': 'Bizepscurl stehend mit Gewicht', // weighted standing curl
  '0854': 'Griffkraft-Drücken mit Handtrainer', // weighted standing hand squeeze
  '0856': 'Svend Press (Hantelscheibe)', // weighted svend press
  '0857': 'Rollout kniend (Bauchroller)', // ab wheel rollout
  '0858': 'Sprints', // wind sprints
  '0859': 'Handgelenkroller', // wrist roller
  '0860': 'Trizeps-Kickback (Kabelzug)', // cable kickback
  '0861': 'Rudern sitzend (Kabelzug)', // cable seated row
  '0862': 'Rumpfdrehung von unten nach oben (Kabelzug)', // cable twist (up-down)
  '0863': 'Außenrotation Schulter liegend (Kurzhantel)', // dumbbell lying external shoulder rotation
  '0864': 'Außenrotation Schulter aufrecht (Kurzhantel)', // dumbbell upright shoulder external rotation
  '0865': 'Hüftheben liegend mit Beinheben', // lying leg-hip raise
  '0866': 'Hüftheben hängend mit Gewicht', // weighted hanging leg-hip raise
  '0868': 'Bizepscurl (Kabelzug)', // cable curl
  '0869': 'Schulterdrücken (Maschine, Variante 2)', // lever shoulder press (variation 2)
  '0870': 'Po-Heben im Unterarmstütz', // butt-ups
  '0871': 'Crunch gehockt', // tuck crunch
  '0872': 'Reverse Crunch', // reverse crunch
  '0873': 'Reverse Crunch (Kabelzug)', // cable reverse crunch
  '0874': 'Crunch stehend mit Seil (Kabelzug)', // cable standing crunch (with rope attachment)
  '0968': 'Bizepscurl abwechselnd (Band)', // band alternating biceps curl
  '0969': 'V-up abwechselnd (Band)', // band alternating v-up
  '0970': 'Klimmzug mit Band', // band assisted pull-up
  '0971': 'Rollout mit Band (Bauchroller)', // band assisted ab wheel rollout
  '0972': 'Fahrrad-Crunch (Band)', // band bicycle crunch
  '0974': 'Latziehen eng (Band)', // band close-grip pulldown
  '0975': 'Liegestütz eng (Band)', // band close-grip push-up
  '0976': 'Konzentrationscurl (Band)', // band concentration curl
  '0977': 'Frontheben seitlich (Band)', // band front lateral raise
  '0978': 'Frontheben (Band)', // band front raise
  '0979': 'Pallof Press horizontal (Band)', // band horizontal pallof press
  '0980': 'Hüftstrecken vorgebeugt (Band)', // band bent-over hip extension
  '0981': 'Klappmesser-Sit-up (Band)', // band jack knife sit-up
  '0983': 'Latziehen einarmig kniend (Band)', // band kneeling one arm pulldown
  '0984': 'Innenrotation Hüfte liegend (Band)', // band lying hip internal rotation
  '0985': 'Crunch mit Drehung kniend (Band)', // band kneeling twisting crunch
  '0986': 'Bizepscurl einarmig über Kopf (Band)', // band one arm overhead biceps curl
  '0987': 'Bulgarische Kniebeuge einarmig (Band)', // band one arm single leg split squat
  '0988': 'Rudern tief einarmig stehend (Band)', // band one arm standing low row
  '0989': 'Brustdrücken einarmig mit Drehung (Band)', // band one arm twisting chest press
  '0990': 'Rudern einarmig mit Drehung sitzend (Band)', // band one arm twisting seated row
  '0991': 'Pull-Through (Band)', // band pull through
  '0992': 'Sit-up mit Drücken (Band)', // band push sit-up
  '0993': 'Reverse Flys (Band)', // band reverse fly
  '0994': 'Handgelenkcurl Obergriff (Band)', // band reverse wrist curl
  '0996': 'Innenrotation Hüfte sitzend (Band)', // band seated hip internal rotation
  '0997': 'Schulterdrücken (Band)', // band shoulder press
  '0998': 'Trizepsstrecken seitlich (Band)', // band side triceps extension
  '0999': 'Wadenheben einbeinig (Band)', // band single leg calf raise
  '1000': 'Zehenheben einbeinig (Band)', // band single leg reverse calf raise
  '1001': 'Bulgarische Kniebeuge (Band)', // band single leg split squat
  '1002': 'Beinheben gestreckt liegend (Band)', // band lying straight leg raise
  '1003': 'Kniebeuge mit Rudern (Band)', // band squat row
  '1004': 'Kniebeuge (Band)', // band squat
  '1005': 'Crunch stehend (Band)', // band standing crunch
  '1007': 'Crunch mit Drehung stehend (Band)', // band standing twisting crunch
  '1008': 'Step-up (Band)', // band step-up
  '1009': 'Kreuzheben mit gestreckten Beinen (Band)', // band stiff leg deadlift
  '1010': 'Kreuzheben mit durchgestreckten Beinen (Band)', // band straight leg deadlift
  '1011': 'Rumpfdrehung sitzend (Band)', // band seated twist
  '1012': 'Schulterdrücken mit Drehung (Band)', // band twisting overhead press
  '1013': 'Latziehen im Untergriff (Band)', // band underhand pulldown
  '1014': 'V-up (Band)', // band v-up
  '1015': 'Pallof Press vertikal (Band)', // band vertical pallof press
  '1016': 'Handgelenkcurl (Band)', // band wrist curl
  '1017': 'Y-Heben (Band)', // band y-raise
  '1018': 'Schulterheben (Band)', // band shrug
  '1022': 'Rudern für die hintere Schulter stehend (Band)', // band standing rear delt row
  '1023': 'Kreuzheben mit gestreckten Beinen und geradem Rücken (Band)', // band straight back stiff leg deadlift
  '1160': 'Burpee', // burpee
  '1167': 'Dynamische Brustdehnung', // dynamic chest stretch
  '1201': 'Burpee (Kurzhantel)', // dumbbell burpee
  '1253': 'Esel-Wadenheben (Maschine)', // lever donkey calf raise
  '1254': 'Bankdrücken (Band)', // band bench press
  '1255': 'Überzüge auf der Negativbank (Langhantel)', // barbell decline pullover
  '1256': 'Negativbankdrücken Untergriff (Langhantel)', // barbell reverse grip decline bench press
  '1257': 'Schrägbankdrücken Untergriff (Langhantel, Variante 2)', // barbell reverse grip incline bench press
  '1258': 'Bankdrücken breit Untergriff (Langhantel)', // barbell wide reverse grip bench press
  '1259': 'Brustdehnung mit Händen hinter dem Kopf (Partner)', // behind head chest stretch
  '1260': 'Negativbankdrücken einarmig (Kabelzug)', // cable decline one arm press
  '1261': 'Negativbankdrücken (Kabelzug)', // cable decline press
  '1262': 'Fliegende einarmig auf der Negativbank (Kabelzug)', // cable one arm decline chest fly
  '1263': 'Fliegende einarmig auf dem Gymnastikball (Kabelzug)', // cable one arm fly on exercise ball
  '1264': 'Fliegende einarmig schräg auf dem Gymnastikball (Kabelzug)', // cable one arm incline fly on exercise ball
  '1265': 'Schrägbankdrücken einarmig (Kabelzug)', // cable one arm incline press
  '1266': 'Schrägbankdrücken einarmig auf dem Gymnastikball (Kabelzug)', // cable one arm incline press on exercise ball
  '1267': 'Brustdrücken einarmig auf dem Gymnastikball (Kabelzug)', // cable one arm press on exercise ball
  '1268': 'Brustdrücken auf dem Gymnastikball (Kabelzug)', // cable press on exercise ball
  '1269': 'Crossover aufrecht stehend (Kabelzug)', // cable standing up straight crossovers
  '1270': 'Crossover für die obere Brust (Kabelzug)', // cable upper chest crossovers
  '1271': 'Dehnung Brust und vordere Schulter', // chest and front of shoulder stretch
  '1272': 'Brustdehnung mit Gymnastikball', // chest stretch with exercise ball
  '1273': 'Klatsch-Liegestütz', // clap push up
  '1274': 'Liegestütz tief auf Kurzhanteln', // deep push up
  '1275': 'Drop-Liegestütz', // drop push up
  '1276': 'Fliegende einarmig auf der Negativbank (Kurzhantel)', // dumbbell decline one arm fly
  '1277': 'Fliegende auf dem Gymnastikball (Kurzhantel)', // dumbbell fly on exercise ball
  '1278': 'Fliegende schräg auf dem Gymnastikball (Kurzhantel)', // dumbbell incline fly on exercise ball
  '1279': 'Fliegende einarmig auf der Schrägbank (Kurzhantel)', // dumbbell incline one arm fly
  '1280': 'Fliegende einarmig schräg auf dem Gymnastikball (Kurzhantel)', // dumbbell incline one arm fly on exercise ball
  '1281': 'Schrägbankdrücken einarmig (Kurzhantel)', // dumbbell incline one arm press
  '1282': 'Schrägbankdrücken einarmig auf dem Gymnastikball (Kurzhantel)', // dumbbell incline one arm press on exercise ball
  '1283': 'Schrägbankdrücken auf dem Gymnastikball (Kurzhantel)', // dumbbell incline press on exercise ball
  '1284': 'Überzüge liegend auf dem Gymnastikball (Kurzhantel)', // dumbbell lying pullover on exercise ball
  '1285': 'Fliegende einarmig auf der Bank (Kurzhantel)', // dumbbell one arm bench fly
  '1286': 'Brust-Fliegende einarmig auf dem Gymnastikball (Kurzhantel)', // dumbbell one arm chest fly on exercise ball
  '1287': 'Negativbankdrücken einarmig (Kurzhantel)', // dumbbell one arm decline chest press
  '1288': 'Fliegende einarmig auf dem Gymnastikball (Kurzhantel)', // dumbbell one arm fly on exercise ball
  '1289': 'Schrägbankdrücken einarmig (Kurzhantel, Variante 2)', // dumbbell one arm incline chest press
  '1290': 'Bankdrücken einarmig auf dem Gymnastikball (Kurzhantel)', // dumbbell one arm press on exercise ball
  '1291': 'Überzüge einarmig auf dem Gymnastikball (Kurzhantel)', // dumbbell one arm pullover on exercise ball
  '1292': 'Fliegende einbeinig auf dem Gymnastikball (Kurzhantel)', // dumbbell one leg fly on exercise ball
  '1293': 'Bankdrücken auf dem Gymnastikball (Kurzhantel)', // dumbbell press on exercise ball
  '1294': 'Überzüge mit Hüftstrecken auf dem Gymnastikball (Kurzhantel)', // dumbbell pullover hip extension on exercise ball
  '1295': 'Überzüge auf dem Gymnastikball (Kurzhantel)', // dumbbell pullover on exercise ball
  '1296': 'Pike-Liegestütz auf dem Gymnastikball', // exercise ball pike push up
  '1297': 'Isometrisches Brustpressen', // isometric chest squeeze
  '1298': 'Bodendrücken einarmig (Kettlebell)', // kettlebell one arm floor press
  '1299': 'Schrägbankdrücken (Maschine)', // lever incline chest press
  '1300': 'Negativbankdrücken (Maschine)', // lever decline chest press
  '1301': 'Brustpresse eng (Maschine)', // machine inner chest press
  '1302': 'Brustpass (Medizinball)', // medicine ball chest pass
  '1303': 'Brustwurf aus dem Dreipunktstand (Medizinball)', // medicine ball chest push from 3 point stance
  '1304': 'Brustwurf mehrfach (Medizinball)', // medicine ball chest push multiple response
  '1305': 'Brustwurf einzeln (Medizinball)', // medicine ball chest push single response
  '1306': 'Plyo-Liegestütz', // plyo push up
  '1307': 'Liegestütz auf dem Bosu (umgedreht)', // push-up on bosu ball (flat side up)
  '1308': 'Bankdrücken breit (Multipresse)', // smith wide grip bench press
  '1309': 'Negativbankdrücken breit (Multipresse)', // smith wide grip decline bench press
  '1310': 'Drop-Liegestütz mit Gewicht', // weighted drop push up
  '1311': 'Liegestütz breit', // wide hand push up
  '1312': 'Brustwurf mit Antritt (Medizinball)', // medicine ball chest push with run release
  '1313': 'Rudern einarmig (Maschine)', // lever unilateral row
  '1314': 'Rückenstrecken auf dem Gymnastikball', // back extension on exercise ball
  '1316': 'Überzüge mit gebeugten Armen (Langhantel)', // barbell bent arm pullover
  '1317': 'Rudern bauchliegend Untergriff auf der Schrägbank (Langhantel)', // barbell reverse grip incline bench row
  '1318': 'Rudern bauchliegend auf der Schrägbank (Kabelzug)', // cable incline bench row
  '1319': 'Rudern mit Handgelenksrotation (Kabelzug)', // cable palm rotational row
  '1320': 'Rudern sitzend über Kreuz mit Seil (Kabelzug)', // cable rope crossover seated row
  '1321': 'Rudern sitzend erhöht mit Seil (Kabelzug)', // cable rope elevated seated row
  '1322': 'Rudern bauchliegend mit Seil auf der Schrägbank (Kabelzug)', // cable rope extension incline bench row
  '1323': 'Rudern sitzend mit Seil (Kabelzug)', // cable rope seated row
  '1324': 'Rudern hoch (Kabelzug)', // cable upper row
  '1325': 'Latziehen breit hinter dem Nacken (Kabelzug)', // cable wide grip rear pulldown behind neck
  '1326': 'Klimmzug im Untergriff (Chin-up)', // chin-up
  '1327': 'Klimmzug eng im Untergriff', // close grip chin-up
  '1328': 'Rudern für die hintere Schulter bauchliegend (Kurzhantel)', // dumbbell lying rear delt row
  '1329': 'Rudern vorgebeugt mit Handgelenksrotation (Kurzhantel)', // dumbbell palm rotational bent over row
  '1330': 'Rudern einarmig Untergriff auf der Schrägbank (Kurzhantel)', // dumbbell reverse grip incline bench one arm row
  '1331': 'Rudern beidarmig Untergriff auf der Schrägbank (Kurzhantel)', // dumbbell reverse grip incline bench two arm row
  '1332': 'Armheben abwechselnd auf dem Gymnastikball', // exercise ball alternating arm ups
  '1333': 'Rückenstrecken mit gestreckten Armen auf dem Gymnastikball', // exercise ball back extension with arms extended
  '1334': 'Rückenstrecken mit Händen hinter dem Kopf auf dem Gymnastikball', // exercise ball back extension with hands behind head
  '1335': 'Rückenstrecken mit Knien in der Luft auf dem Gymnastikball', // exercise ball back extension with knees off ground
  '1336': 'Rückenstrecken mit Rotation auf dem Gymnastikball', // exercise ball back extension with rotation
  '1338': 'Gymnastikball-Umarmung (Rückendehnung)', // exercise ball hug
  '1339': 'Latissimus-Dehnung mit Gymnastikball', // exercise ball lat stretch
  '1341': 'Dehnung unterer Rücken auf dem Gymnastikball (Pyramide)', // exercise ball lower back stretch (pyramid)
  '1342': 'Latissimus-Dehnung seitlich liegend auf dem Gymnastikball', // exercise ball lying side lat stretch
  '1343': 'Beinheben bauchliegend auf dem Gymnastikball', // exercise ball prone leg raise
  '1344': 'Rudern vorgebeugt im Untergriff (SZ-Stange)', // ez bar reverse grip bent over row
  '1345': 'Rudern beidarmig (Kettlebell)', // kettlebell two arm row
  '1346': 'Latissimus-Dehnung kniend', // kneeling lat stretch
  '1347': 'Latziehen breit einarmig (Maschine)', // lever one arm lateral wide pulldown
  '1348': 'Rudern vertikal Untergriff (Maschine)', // lever reverse grip vertical row
  '1349': 'T-Bar-Rudern umgekehrt (Maschine)', // lever reverse t-bar row
  '1350': 'Rudern sitzend (Maschine)', // lever seated row
  '1351': 'T-Bar-Rudern Untergriff (Maschine)', // lever t-bar reverse grip row
  '1352': 'Rückenstrecken am Boden', // lower back curl
  '1353': 'Medizinball fangen und über Kopf werfen', // medicine ball catch and overhead throw
  '1354': 'Ball Slam (Medizinball)', // medicine ball overhead slam
  '1355': 'Latissimus-Dehnung einarmig an der Wand', // one arm lat stretch against wall
  '1356': 'Hohes Rudern einarmig (Maschine)', // lever one arm lateral high row
  '1358': 'Dehnung seitlich liegend am Boden', // side lying floor stretch
  '1359': 'Rudern vorgebeugt (Multipresse)', // smith bent over row
  '1360': 'Rudern einarmig (Multipresse)', // smith one arm row
  '1361': 'Rudern vorgebeugt Untergriff (Multipresse)', // smith reverse grip bent over row
  '1362': 'Sphinx (Rückendehnung)', // sphinx
  '1363': 'Wirbelsäulen-Dehnung', // spine stretch
  '1364': 'Beckenkippen stehend', // standing pelvic tilt
  '1365': 'Dehnung oberer Rücken', // upper back stretch
  '1366': 'Heraufschauender Hund', // upward facing dog
  '1367': 'Klimmzug breit hinter dem Nacken', // wide grip rear pull-up
  '1368': 'Fußkreisen', // ankle circles
  '1369': 'Wadenheben beidbeinig (Band)', // band two legs calf raise (band under both feet)
  '1370': 'Wadenheben am Boden (Langhantel)', // barbell floor calf raise
  '1371': 'Wadenheben sitzend (Langhantel, Variante 2)', // barbell seated calf raise
  '1372': 'Wadenheben stehend auf Erhöhung (Langhantel)', // barbell standing calf raise
  '1373': 'Wadenheben stehend', // bodyweight standing calf raise
  '1374': 'Box Jump abwärts mit einbeiniger Landung', // box jump down with one leg stabilization
  '1375': 'Wadenheben stehend (Kabelzug)', // cable standing calf raise
  '1376': 'Wadenheben einbeinig stehend (Kabelzug)', // cable standing one leg calf raise
  '1377': 'Wadendehnung an der Wand', // calf stretch with hands against wall
  '1378': 'Wadendehnung mit Seil', // calf stretch with rope
  '1379': 'Wadenheben sitzend (Kurzhantel)', // dumbbell seated calf raise
  '1380': 'Wadenheben einbeinig sitzend Hammergriff (Kurzhantel)', // dumbbell seated one leg calf raise (hammer grip)
  '1381': 'Wadenheben einbeinig sitzend Untergriff (Kurzhantel)', // dumbbell seated one leg calf raise (palm up)
  '1382': 'Wadenheben mit Gymnastikball an der Wand (Kurzhantel)', // exercise ball wall calf raise
  '1383': 'Wadenheben an der Hackenschmidt-Maschine', // hack calf raise
  '1384': 'Wadenheben einbeinig an der Hackenschmidt-Maschine', // hack one leg calf raise
  '1385': 'Wadenheben in der Hocke an der Beinpresse (Maschine)', // lever seated squat calf raise on leg press machine
  '1386': 'Esel-Wadenheben einbeinig', // one leg donkey calf raise
  '1387': 'Wadenheben einbeinig am Boden', // one leg floor calf raise
  '1388': 'Dehnung Wadenbeinmuskeln (Seil)', // peroneals stretch
  '1389': 'Dehnung hinterer Schienbeinmuskel (Seil)', // posterior tibialis stretch
  '1390': 'Wadendehnung sitzend', // seated calf stretch
  '1391': 'Wadendrücken an der Beinpresse (Maschine)', // sled calf press on leg press
  '1392': 'Wadendrücken einbeinig an der Beinpresse (Maschine)', // sled one leg calf press on leg press
  '1393': 'Wadenheben einbeinig am Boden (Multipresse)', // smith one leg floor calf raise
  '1394': 'Wadenheben umgekehrt / Zehenheben (Multipresse, Variante 2)', // smith reverse calf raises
  '1395': 'Wadenheben einbeinig sitzend (Multipresse)', // smith seated one leg calf raise
  '1396': 'Zehenheben (Multipresse)', // smith toe raise
  '1397': 'Wadenheben stehend am Boden', // standing calf raise (floor)
  '1398': 'Wadendehnung stehend', // standing calf stretch
  '1399': 'Dips am Boden', // bench dip on floor
  '1401': 'Muscle-up an der senkrechten Stange', // muscle-up (on vertical bar)
  '1403': 'Nackendehnung zur Seite', // neck side stretch
  '1405': 'Brustdehnung hinter dem Rücken', // back pec stretch
  '1407': 'Wadendehnung mit Händen an der Wand', // calf push stretch with hands against wall
  '1408': 'Hüftheben (Band)', // band hip lift
  '1409': 'Glute Bridge / Hüftheben (Langhantel)', // barbell glute bridge
  '1410': 'Ausfallschritt seitlich (Langhantel)', // barbell lateral lunge
  '1411': 'Handgelenkcurl Obergriff über der Bank (Langhantel)', // barbell palms down wrist curl over a bench
  '1412': 'Handgelenkcurl Untergriff über der Bank (Langhantel)', // barbell palms up wrist curl over a bench
  '1413': 'Reverse Curl einarmig (Kabelzug)', // cable reverse one arm curl
  '1414': 'Scottcurl einarmig im Obergriff (Kurzhantel)', // dumbbell one arm reverse preacher curl
  '1415': 'Handgelenkcurl einarmig Neutralgriff sitzend (Kurzhantel)', // dumbbell one arm seated neutral wrist curl
  '1416': 'Unterkörperrotation einbeinig bauchliegend auf dem Gymnastikball', // exercise ball one leg prone lower body rotation
  '1417': 'Beinbeuger einbeinig mit Diagonalkick auf dem Gymnastikball', // exercise ball one legged diagonal kick hamstring curl
  '1418': 'Knie zur Brust ziehen', // hug knees to chest
  '1419': 'Iron-Cross-Dehnung', // iron cross stretch
  '1420': 'Sprungkniebeuge aus dem Knien (Langhantel)', // kneeling jump squat
  '1421': 'Liegestütz modifiziert auf die Unterarme', // modified push up to lower arms
  '1422': 'Beckenkippen in die Brücke', // pelvic tilt into bridge
  '1423': 'Reverse Hyperextension auf der Flachbank', // reverse hyper on flat bench
  '1424': 'Gesäßdehnung sitzend', // seated glute stretch
  '1425': 'Beinpresse einbeinig 45° (Maschine)', // sled 45 degrees one leg press
  '1426': 'Handgelenkcurl sitzend (Multipresse)', // smith seated wrist curl
  '1427': 'Abduktion mit gestrecktem Bein', // straight leg outer hip abductor
  '1428': 'Handgelenkkreisen', // wrist circles
  '1429': 'Klimmzug breit', // wide grip pull-up
  '1430': 'Dips (Brust, an der Dip-Station)', // chest dip (on dip-pull-up cage)
  '1431': 'Klimmzug im Untergriff stehend unterstützt (Maschine)', // assisted standing chin-up
  '1432': 'Klimmzug stehend unterstützt (Maschine)', // assisted standing pull-up
  '1433': 'Frontkniebeuge im Umsetzgriff (Multipresse)', // smith front squat (clean grip)
  '1434': 'Low-Bar-Kniebeuge (Multipresse)', // smith low bar squat
  '1435': 'Low-Bar-Kniebeuge (Langhantel)', // barbell low bar squat
  '1436': 'High-Bar-Kniebeuge (Langhantel)', // barbell high bar squat
  '1437': 'Fingercurl (Kurzhantel)', // dumbbell finger curls
  '1438': 'Schulterdrücken beidarmig sitzend (Kettlebell)', // kettlebell seated two arm military press
  '1439': 'Schulterheben ohne Griff (Maschine, Variante 2)', // lever gripless shrug v. 2
  '1441': 'Handgelenkcurl Obergriff einarmig über der Bank (Kurzhantel)', // dumbbell over bench one arm reverse wrist curl
  '1451': 'Dips sitzend (Maschine)', // lever seated dip
  '1452': 'Crunch sitzend (Maschine)', // lever seated crunch
  '1456': 'Schulterdrücken eng stehend (Langhantel)', // barbell standing close grip military press
  '1457': 'Schulterdrücken stehend (Langhantel)', // barbell standing wide military press
  '1458': 'Bizepscurl sitzend (SZ-Stange)', // ez barbell seated curls
  '1459': 'Rumänisches Kreuzheben (Kurzhantel)', // dumbbell romanian deadlift
  '1460': 'Ausfallschritt gehend', // walking lunge
  '1461': 'Kniebeuge (Langhantel, Ansicht von hinten)', // barbell full squat (back pov)
  '1462': 'Kniebeuge (Langhantel, Ansicht von der Seite)', // barbell full squat (side pov)
  '1463': 'Beinpresse 45° (Maschine, Ansicht von der Seite)', // sled 45° leg press (side pov)
  '1464': 'Beinpresse 45° (Maschine, Ansicht von hinten)', // sled 45° leg press (back pov)
  '1466': 'Hüftheben mit Drehung', // twist hip lift
  '1467': 'Liegestütz auf den Unterarmen', // push-up on lower arms
  '1468': 'Krebsgang mit Zehentippen', // crab twist toe touch
  '1471': 'Inchworm / Raupe', // inchworm
  '1472': 'Weitsprung vorwärts', // forward jump
  '1473': 'Sprung rückwärts', // backward jump
  '1476': 'Kniebeuge einbeinig', // one leg squat
  '1479': 'Schrägbankdrücken (Maschine, Variante 2)', // lever incline chest press v. 2
  '1489': 'Sissy Squat', // sissy squat
  '1490': 'Wadenheben auf der Treppenstufe', // standing calf raise (on a staircase)
  '1494': 'Schmetterlingssitz (Yoga)', // butterfly yoga pose
  '1495': 'Seitlicher Crunch', // oblique crunch
  '1496': 'Reifenschläge (Vorschlaghammer)', // sledgehammer strikes
  '1511': 'Beinbeuger-Dehnung', // hamstring stretch
  '1512': 'Quadrizeps-Dehnung im Vierfüßlerstand', // all fours quad stretch
  '1545': 'Zercher-Kniebeuge tief (Langhantel)', // barbell full zercher squat
  '1548': 'Beindehnung auf dem Stuhl', // chair leg extended stretch
  '1559': 'Hüftbeuger-Dehnung mit Gymnastikball', // exercise ball hip flexor stretch
  '1560': 'Beinbeuger-Dehnung sitzend auf dem Gymnastikball', // exercise ball seated hamstring stretch
  '1564': 'Hüftbeuger- und Quadrizeps-Dehnung (Seil)', // intermediate hip flexor and quad stretch
  '1576': 'Beinbeuger-Dehnung mit erhöhtem Bein', // leg up hamstring stretch
  '1582': 'Liegende Großzehen-Haltung mit Seil (Yoga)', // reclining big toe pose with rope
  '1585': 'Läuferdehnung', // runner's stretch
  '1587': 'Grätschsitz-Sequenz (Yoga)', // seated wide angle pose sequence
  '1599': 'Beinbeuger- und Wadendehnung stehend (Gurt)', // standing hamstring and calf stretch with strap
  '1604': "World's Greatest Stretch", // world's greatest stretch
  '1614': 'Scottcurl (Maschine, Variante 2)', // lever preacher curl v. 2
  '1615': 'Hammer-Scottcurl (Maschine)', // lever hammer grip preacher curl
  '1616': 'Scottcurl im Obergriff (Maschine)', // lever reverse grip preacher curl
  '1617': 'Negativbankdrücken einarmig Neutralgriff (Kurzhantel)', // dumbbell decline one arm hammer press
  '1618': 'Schrägbankdrücken Neutralgriff auf dem Gymnastikball (Kurzhantel)', // dumbbell incline hammer press on exercise ball
  '1619': 'Schrägbankdrücken einarmig Neutralgriff (Kurzhantel)', // dumbbell incline one arm hammer press
  '1620': 'Schrägbankdrücken einarmig Neutralgriff auf dem Gymnastikball (Kurzhantel)',
  '1621': 'Bankdrücken einarmig Neutralgriff auf dem Gymnastikball (Kurzhantel)', // dumbbell one arm hammer press on exercise ball
  '1622': 'Bankdrücken einarmig Untergriff (Kurzhantel)', // dumbbell one arm reverse grip press
  '1623': 'Schrägbankdrücken Hammergriff (Kurzhantel, Variante 2)', // dumbbell palms in incline bench press
  '1624': 'Bankdrücken Untergriff (Kurzhantel)', // dumbbell reverse bench press
  '1625': 'Negativbankdrücken eng (Multipresse)', // smith machine decline close grip bench press
  '1626': 'Negativbankdrücken eng Untergriff (Multipresse)', // smith machine reverse decline close grip bench press
  '1627': 'Scottcurl eng (SZ-Stange)', // ez barbell close grip preacher curl
  '1628': 'Spider Curl (SZ-Stange, Variante 2)', // ez barbell spider curl
  '1629': 'Bizepscurl breit stehend (Langhantel, Variante 2)', // barbell standing wide grip biceps curl
  '1630': 'Bizepscurl eng (Kabelzug)', // cable close grip curl
  '1631': 'Konzentrationscurl (Kabelzug)', // cable concentration curl
  '1632': 'Drag Curl (Kabelzug)', // cable drag curl
  '1633': 'Scottcurl einarmig (Kabelzug)', // cable one arm preacher curl
  '1634': 'Bizepscurl liegend (Kabelzug)', // cable lying bicep curl
  '1635': 'Scottcurl einarmig im Obergriff (Kabelzug)', // cable one arm reverse preacher curl
  '1636': 'Bizepscurl über Kopf (Kabelzug)', // cable overhead curl
  '1637': 'Bizepscurl über Kopf auf dem Gymnastikball (Kabelzug)', // cable overhead curl on exercise ball
  '1638': 'Bizepscurl am Latzug (Kabelzug)', // cable pulldown bicep curl
  '1639': 'Hammer-Scottcurl mit Seil (Kabelzug)', // cable rope hammer preacher curl
  '1640': 'Hammer-Scottcurl einarmig mit Seil (Kabelzug)', // cable rope one arm hammer preacher curl
  '1641': 'Bizepscurl sitzend (Kabelzug)', // cable seated curl
  '1642': 'Konzentrationscurl einarmig sitzend (Kabelzug)', // cable seated one arm concentration curl
  '1643': 'Bizepscurl über Kopf sitzend (Kabelzug)', // cable seated overhead curl
  '1644': 'Bizepscurl in der Hocke (Kabelzug)', // cable squatting curl
  '1645': 'Bizepscurl beidarmig auf der Schrägbank (Kabelzug)', // cable two arm curl on incline bench
  '1646': 'Hammer-Scottcurl abwechselnd (Kurzhantel)', // dumbbell alternate hammer preacher curl
  '1647': 'Scottcurl abwechselnd (Kurzhantel)', // dumbbell alternate preacher curl
  '1648': 'Hammercurl abwechselnd sitzend (Kurzhantel)', // dumbbell alternate seated hammer curl
  '1649': 'Bizepscurl abwechselnd mit Beinheben auf dem Gymnastikball (Kurzhantel)',
  '1650': 'Bizepscurl abwechselnd sitzend auf dem Gymnastikball (Kurzhantel)', // dumbbell alternating seated bicep curl on exercise ball
  '1651': 'Bizepscurl mit Ausfallschritt und Bowling-Bewegung (Kurzhantel)', // dumbbell bicep curl lunge with bowling motion
  '1652': 'Bizepscurl mit Beinheben auf dem Gymnastikball (Kurzhantel)', // dumbbell bicep curl on exercise ball with leg raised
  '1653': 'Bizepscurl im Storchenstand (Kurzhantel)', // dumbbell bicep curl with stork stance
  '1654': 'Reverse Curl (Kurzhantel)', // dumbbell biceps curl reverse
  '1655': 'Bizepscurl mit Kniebeuge (Kurzhantel)', // dumbbell biceps curl squat
  '1656': 'Bizepscurl im V-Sitz auf dem Bosu (Kurzhantel)', // dumbbell biceps curl v sit on bosu ball
  '1657': 'Hammercurl diagonal (Kurzhantel, Variante 2)', // dumbbell cross body hammer curl v. 2
  '1658': 'Ausfallschritt mit Bizepscurl (Kurzhantel)', // dumbbell lunge with bicep curl
  '1659': 'Hammercurl auf dem Gymnastikball (Kurzhantel)', // dumbbell hammer curl on exercise ball
  '1660': 'Bizepscurl kniend am Gymnastikball (Kurzhantel)', // dumbbell kneeling bicep curl exercise ball
  '1661': 'Bizepscurl rücklings auf der Bank (Kurzhantel, Variante 2)', // dumbbell lying supine biceps curl
  '1662': 'Bizepscurl breit liegend (Kurzhantel)', // dumbbell lying wide curl
  '1663': 'Hammer-Scottcurl einarmig (Kurzhantel)', // dumbbell one arm hammer preacher curl
  '1664': 'Bizepscurl hoch (Kurzhantel)', // dumbbell high curl
  '1665': 'Bizepscurl einarmig bauchliegend (Kurzhantel)', // dumbbell one arm prone curl
  '1666': 'Hammercurl einarmig bauchliegend (Kurzhantel)', // dumbbell one arm prone hammer curl
  '1667': 'Spider Curl einarmig im Obergriff (Kurzhantel)', // dumbbell one arm reverse spider curl
  '1668': 'Bizepscurl einarmig sitzend auf dem Gymnastikball (Kurzhantel)', // dumbbell one arm seated bicep curl on exercise ball
  '1669': 'Hammercurl einarmig sitzend (Kurzhantel)', // dumbbell one arm seated hammer curl
  '1670': 'Bizepscurl einarmig stehend (Kurzhantel)', // dumbbell one arm standing curl
  '1671': 'Hammercurl einarmig stehend (Kurzhantel)', // dumbbell one arm standing hammer curl
  '1672': 'Zottman-Scottcurl einarmig (Kurzhantel)', // dumbbell one arm zottman preacher curl
  '1673': 'Scottcurl über dem Gymnastikball (Kurzhantel)', // dumbbell preacher curl over exercise ball
  '1674': 'Hammercurl bauchliegend auf der Schrägbank (Kurzhantel)', // dumbbell prone incline hammer curl
  '1675': 'Spider Curl im Obergriff (Kurzhantel)', // dumbbell reverse spider curl
  '1676': 'Hammercurl abwechselnd sitzend auf dem Gymnastikball (Kurzhantel)', // dumbbell seated alternate hammer curl on exercise ball
  '1677': 'Bizepscurl sitzend auf der Bank (Kurzhantel)', // dumbbell seated bicep curl
  '1678': 'Hammercurl sitzend (Kurzhantel)', // dumbbell seated hammer curl
  '1679': 'Bizepscurl einarmig sitzend mit Beinheben auf dem Gymnastikball (Kurzhantel)',
  '1680': 'Bizepscurl einarmig über die Schrägbank (Kurzhantel, Variante 2)', // dumbbell standing one arm curl over incline bench
  '1682': 'Konzentrationscurl eng sitzend (SZ-Stange)', // ez bar seated close grip concentration curl
  '1683': 'Bizepscurl (Multipresse)', // smith machine bicep curl
  '1684': 'Step-up mit Einbeinstand und Bizepscurl (Kurzhantel)', // dumbbell step up single leg balance with bicep curl
  '1685': 'Kniebeuge mit Strecken nach oben', // squat to overhead reach
  '1686': 'Kniebeuge mit Strecken nach oben und Drehung', // squat to overhead reach with twist
  '1687': 'Schritt zurück mit Strecken nach oben', // posterior step to overhead reach
  '1688': 'Ausfallschritt mit Rumpfdrehung', // lunge with twist
  '1689': 'Liegestütz mit Zug (Push and Pull)', // push and pull bodyweight
  '1700': 'Push Press (Kurzhantel)', // dumbbell push press
  '1701': 'Liegestütz eng auf dem Medizinball', // medicine ball close grip push up
  '1705': 'Kniebeuge auf dem Bosu', // squat on bosu ball
  '1707': 'Rumpfdrehung bauchliegend auf dem Gymnastikball', // prone twist on stability ball
  '1708': 'Wadendehnung liegend (Partner)', // assisted lying calves stretch
  '1709': 'Gesäßdehnung liegend (Partner)', // assisted lying glutes stretch
  '1710': 'Gesäß- und Piriformis-Dehnung liegend (Partner)', // assisted lying gluteus and piriformis stretch
  '1712': 'Adduktoren-Dehnung seitlich liegend (Partner)', // assisted side lying adductor stretch
  '1713': 'Quadrizeps-Dehnung bauchliegend (Partner)', // assisted prone lying quads stretch
  '1714': 'Dehnung gerader Oberschenkelmuskel bauchliegend (Partner)', // assisted prone rectus femoris stretch
  '1716': 'Brustdehnung sitzend mit Gymnastikball (Partner)', // assisted seated pectoralis major stretch with stability ball
  '1717': 'Kniebeuge mit Rudern mit Seil (Kabelzug)', // cable squat row (with rope attachment)
  '1718': 'Trizepsstrecken eng hinter dem Nacken sitzend (Langhantel)', // barbell seated close grip behind neck triceps extension
  '1719': 'Schrägbankdrücken eng (Langhantel)', // barbell incline close grip bench press
  '1720': 'Trizepsstrecken liegend hinter den Kopf (Langhantel)', // barbell lying back of the head tricep extension
  '1721': 'Stirndrücken Untergriff (Langhantel)', // barbell reverse grip skullcrusher
  '1722': 'Trizepsdrücken über Kopf vom oberen Zug (Kabelzug)', // cable high pulley overhead tricep extension
  '1723': 'Trizepsdrücken einarmig (Kabelzug)', // cable one arm tricep pushdown
  '1724': 'Trizepsdrücken über Kopf vom oberen Zug (Kabelzug, Seil)', // cable rope high pulley overhead tricep extension
  '1725': 'Trizepsstrecken auf der Schrägbank (Kabelzug, Seil)', // cable rope incline tricep extension
  '1726': 'Trizepsstrecken liegend am Boden (Kabelzug, Seil)', // cable rope lying on floor tricep extension
  '1727': 'Trizepsdrücken über Kopf einarmig Untergriff stehend (Kabelzug)',
  '1728': 'Trizeps-Kickback beidarmig (Kabelzug)', // cable two arm tricep kickback
  '1729': 'Trizepsstrecken abwechselnd liegend (Kurzhantel)', // dumbbell lying alternate extension
  '1730': 'Trizeps-Kickback abwechselnd vorgebeugt sitzend (Kurzhantel)', // dumbbell seated bent over alternate kickback
  '1731': 'Bankdrücken eng (Kurzhantel, Variante 2)', // dumbbell close grip press
  '1732': 'Ausfallschritt mit Trizepsstrecken (Kurzhantel)', // dumbbell forward lunge triceps extension
  '1733': 'Trizepsstrecken beidarmig auf der Schrägbank (Kurzhantel)', // dumbbell incline two arm extension
  '1734': 'Trizeps-Kickback auf dem Gymnastikball (Kurzhantel)', // dumbbell kickbacks on exercise ball
  '1735': 'Trizepsstrecken einarmig liegend (Kurzhantel)', // dumbbell lying single extension
  '1736': 'French Press einarmig auf dem Gymnastikball (Kurzhantel)', // dumbbell one arm french press on exercise ball
  '1737': 'Trizepsstrecken vorgebeugt sitzend (Kurzhantel)', // dumbbell seated bent over triceps extension
  '1738': 'Trizepsdrücken über Kopf einarmig Untergriff sitzend (Kurzhantel)',
  '1739': 'Trizeps-Kickback abwechselnd stehend (Kurzhantel)', // dumbbell standing alternating tricep kickback
  '1740': 'Trizepsstrecken einarmig vorgebeugt stehend (Kurzhantel)', // dumbbell standing bent over one arm triceps extension
  '1741': 'Trizepsstrecken beidarmig vorgebeugt stehend (Kurzhantel)', // dumbbell standing bent over two arm triceps extension
  '1742': 'Trizeps-Kickback im Storchenstand (Kurzhantel)', // dumbbell tricep kickback with stork stance
  '1743': 'Bankdrücken mit Drehung (Kurzhantel)', // dumbbell twisting bench press
  '1744': 'Dips am Gymnastikball', // exercise ball dip
  '1745': 'Trizeps-Dehnung sitzend auf dem Gymnastikball', // exercise ball seated triceps stretch
  '1746': 'Trizepsstrecken rücklings auf dem Gymnastikball (Kurzhantel)', // exercise ball supine triceps extension
  '1747': 'French Press auf dem Gymnastikball (SZ-Stange)', // ez bar french press on exercise ball
  '1748': 'Trizepsstrecken eng liegend hinter den Kopf (SZ-Stange)', // ez bar lying close grip triceps extension behind head
  '1749': 'French Press stehend (SZ-Stange)', // ez bar standing french press
  '1750': 'Brustwurf rücklings (Medizinball)', // medicine ball supine chest throw
  '1751': 'Pin Press / Bankdrücken aus den Ablagen (Langhantel)', // barbell pin presses
  '1752': 'Trizepsstrecken auf der Schrägbank (Multipresse)', // smith machine incline tricep extension
  '1753': 'Dips zwischen drei Bänken', // three bench dip
  '1754': 'Dips zwischen drei Bänken mit Gewicht', // weighted three bench dips
  '1755': 'Dips mit Zusatzgewicht (Trizeps)', // weighted tricep dips
  '1756': 'Kreuzheben einbeinig (Langhantel)', // barbell single leg deadlift
  '1757': 'Kreuzheben einbeinig (Kurzhantel)', // dumbbell single leg deadlift
  '1758': 'Sit-up mit Unterstützung', // assisted sit-up
  '1759': 'Pistol Squat', // pistol squat
  '1760': 'Goblet Squat (Kurzhantel)', // dumbbell goblet squat
  '1761': 'Knieheben hängend schräg', // hanging oblique knee raise
  '1763': 'Klimmzug schulterbreit', // shoulder grip pull-up
  '1764': 'Hüftheben hängend', // hanging leg hip raise
  '1765': 'Aufrechtes Rudern (Kurzhantel, Ansicht von hinten)', // dumbbell upright row (back pov)
  '1766': 'Nordic Curl (Variante 2)', // self assisted inverse leg curl
  '1767': 'Dips mit Zusatzgewicht am hohen Barren', // weighted triceps dip on high parallel bars
  '1769': 'Bizepscurl seitlich liegend am Körpergewicht', // bodyweight side lying biceps curl
  '1770': 'Konzentrationscurl am eigenen Bein', // biceps leg concentration curl
  '1771': 'Trizepsstrecken kniend am Körpergewicht', // bodyweight kneeling triceps extension
  '1772': 'Ellbogenheben rücklings (Reverse Push-up)', // elbow lift (reverse push-up)
  '1773': 'Rudern einarmig mit Handtuch', // one arm towel row
  '1774': 'Seitstütz mit Abduktion', // side bridge hip abduction
  '1775': 'Seitstütz mit Adduktion', // side plank hip adduction
  '2133': "Farmer's Walk (Kurzhantel)", // farmer's walk
  '2135': 'Unterarmstütz / Plank mit Gewicht', // weighted front plank
  '2136': 'Cuban Press (Kurzhantel, Variante 2)', // dumbbell cuban press v. 2
  '2137': 'Arnold Press (Kurzhantel)', // dumbbell arnold press
  '2138': 'Fahrradergometer (Variante 2)', // stationary bike run v. 3
  '2139': 'Armergometer', // arm ergometer
  '2141': 'Crosstrainer', // walk elliptical cross trainer
  '2142': 'Ski-Ergometer', // ski ergometer
  '2143': 'Hantelkreisen um den Körper (Kurzhantel)', // dumbbell standing around the world
  '2144': 'Brustdrücken sitzend (Kabelzug)', // cable seated chest press
  '2186': 'Trizepsstrecken auf der Negativbank (SZ-Stange)', // ez barbell decline triceps extension
  '2187': 'Bankdrücken eng Untergriff (Langhantel)', // barbell reverse close-grip bench press
  '2188': 'Trizepsdrücken über Kopf sitzend (Kurzhantel)', // dumbbell seated triceps extension
  '2189': 'Trizepsdrücken über Kopf sitzend (Kurzhantel, Variante 2)', // dumbbells seated triceps extension
  '2202': 'Hüftdehnung mit Faszienrolle', // roller hip stretch
  '2203': 'Schultermobilisation sitzend (Faszienrolle)', // roller seated shoulder mobilization
  '2204': 'Body Saw (Faszienrolle)', // roller body saw
  '2205': 'Hüft- und Latissimus-Dehnung (Faszienrolle)', // roller hip lat stretch
  '2206': 'Reverse Crunch (Faszienrolle)', // roller reverse crunch
  '2207': 'Latissimus-Dehnung seitlich (Faszienrolle)', // roller side lat stretch
  '2208': 'Rückendehnung (Faszienrolle)', // roller back stretch
  '2209': 'Schultermobilisation einbeinig sitzend (Faszienrolle)', // roller seated single leg shoulder mobilization
  '2271': 'Linker Haken (Boxen)', // left hook (boxing)
  '2285': 'Überzüge (Maschine)', // lever pullover
  '2286': 'Hüftstrecken (Maschine)', // lever hip extension
  '2287': 'Beinpresse abwechselnd (Maschine)', // lever alternate leg press
  '2288': 'Griffkraft-Training (Maschine)', // lever hand gripper
  '2289': 'Wadendrücken (Maschine)', // lever calf press
  '2292': 'Reverse Flys vorgebeugt (Kurzhantel, Variante 2)', // dumbbell rear delt raise
  '2293': 'Zottman-Scottcurl stehend (Kurzhantel)', // dumbbell standing zottman preacher curl
  '2294': 'Zottman-Scottcurl (Kurzhantel)', // dumbbell zottman preacher curl
  '2297': 'Crunch auf dem Gymnastikball mit voller Bewegung', // stability ball crunch (full range hands behind head)
  '2298': 'Rudern am Körpergewicht an der Bank', // inverted row on bench
  '2300': 'Rudern am Körpergewicht mit gebeugten Knien', // inverted row bent knees
  '2311': 'Stepper', // walking on stepmill
  '2312': 'Ellbogen-zum-Knie-Crunch liegend', // lying elbow to knee
  '2315': 'Wadenheben rotierend (Maschine)', // lever rotary calf
  '2317': 'Seitheben mit gebeugten Armen sitzend (Kurzhantel)', // dumbbell seated bent arm lateral raise
  '2318': 'Schulterdrücken (Maschine, Variante 3)', // lever shoulder press (variation 3)
  '2321': 'Bizepscurl nach außen stehend (Kurzhantel)', // dumbbell standing inner biceps curl
  '2327': 'Rudern im Untergriff (Kurzhantel)', // dumbbell reverse grip row
  '2328': 'Liegestütz eng auf dem Gymnastikball', // narrow push-up on exercise ball
  '2329': 'Wirbelsäulen-Rotation', // spine twist
  '2330': 'Latziehen (Kabelzug)', // cable lat pulldown full range of motion
  '2331': 'Fahrrad-Crosstrainer', // cycle cross trainer
  '2333': 'Pendelschwung hängend mit gestreckten Beinen', // arm slingers hanging straight legs
  '2334': 'Wadendrücken liegend (Maschine)', // sled lying calf press
  '2335': 'Wadendrücken sitzend (Maschine)', // lever seated calf press
  '2355': 'Pendelschwung hängend mit gebeugten Knien', // arm slingers hanging bent knee legs
  '2363': 'Dips breit am hohen Barren (Brust)', // wide-grip chest dip on high parallel bars
  '2364': 'Dips breit kniend unterstützt (Maschine)', // assisted wide-grip chest dip (kneeling)
  '2368': 'Split Squat', // split squats
  '2371': 'Russian Twist mit Gewicht (Variante 2)', // weighted russian twist v. 2
  '2397': 'Scott Press (Kurzhantel)', // dumbbell scott press
  '2398': 'Liegestütz eng auf den Knien', // close-grip push-up (on knees)
  '2399': 'Rumpfdrehung sitzend (Kabelzug)', // cable seated twist
  '2400': 'Nordic Curl am Kabelzugturm', // inverse leg curl (on pull-up cable machine)
  '2401': 'Bizepscurl mit Arm Blaster (Kurzhantel)', // dumbbell biceps curl (with arm blaster)
  '2402': 'Hammercurl mit Arm Blaster (Kurzhantel)', // dumbbell hammer curls (with arm blaster)
  '2403': 'Bizepscurl abwechselnd mit Arm Blaster (Kurzhantel)', // dumbbell alternate biceps curl (with arm blaster)
  '2404': 'Bizepscurl mit Arm Blaster (SZ-Stange)', // ez-bar biceps curl (with arm blaster)
  '2405': 'Trizepsdrücken mit Arm Blaster (Kabelzug, V-Griff)', // cable triceps pushdown (v-bar) (with arm blaster)
  '2406': 'Trizepsdrücken im Untergriff mit Arm Blaster (Kabelzug, SZ-Griff)',
  '2407': 'Bizepscurl mit Arm Blaster (Langhantel)', // barbell biceps curl (with arm blaster)
  '2414': 'Konzentrationscurl stehend (Langhantel)', // barbell standing concentration curl
  '2429': 'Frosch-Crunch', // frog crunch
  '2432': 'Bankdrücken eng (SZ-Stange)', // ez-bar close-grip bench press
  '2459': 'Reifen wenden', // tire flip
  '2462': 'Dips an der geraden Stange', // chest dip on straight bar
  '2464': 'Kajak-Rudern nach Thibaudeau (Kabelzug)', // cable thibaudeau kayak row
  '2466': 'Bergsteiger diagonal aus der Brücke', // bridge - mountain climber (cross body)
  '2470': 'Reverse Flys bauchliegend am Boden (Kurzhantel)', // dumbbell lying on floor rear delt raise
  '2567': 'Piriformis-Dehnung sitzend', // seated piriformis stretch
  '2571': 'Froschdehnung wippend', // rocking frog stretch
  '2611': 'Beinpresse einbeinig horizontal (Maschine)', // lever horizontal one leg press
  '2612': 'Seilspringen', // jump rope
  '2616': 'Latziehen mit V-Griff (Kabelzug)', // cable lateral pulldown with v-bar
  '2705': 'Pronation liegend am Boden (Kurzhantel)', // dumbbell lying pronation on floor
  '2706': 'Supination liegend am Boden (Kurzhantel)', // dumbbell lying supination on floor
  '2736': 'Latziehen im Untergriff (Maschine, Variante 2)', // lever reverse grip lateral pulldown
  '2741': 'Bizepscurl breit stehend (SZ-Stange)', // ez-barbell standing wide grip biceps curl
  '2796': 'Step-up mit Ausfallschritt (Kurzhantel)', // dumbbell step-up lunge
  '2798': 'Sprungkniebeuge mit Ausfallschritt rückwärts (Langhantel)', // barbell squat jump step rear lunge
  '2799': 'Beinheben abwechselnd sitzend (Langhantel)', // barbell seated alternate leg raise
  '2800': 'Beinheben abwechselnd sitzend (Langhantel, Variante 2)', // barbell seated alternate leg raise (variation 2)
  '2801': 'Beinheben mit Drehung (Variante 2)', // twisted leg raise (variation 2)
  '2802': 'Beinheben mit Drehung', // twisted leg raise
  '2803': 'Kniebeuge mit Abstützen (Kurzhantel)', // dumbbell supported squat
  '2805': 'Kreuzheben einbeinig mit Stepbox-Stütze (Kurzhantel)', // dumbbell single leg deadlift with stepbox support
  '2808': 'Sumo Pull-Through (Kurzhantel)', // dumbbell sumo pull through
  '2810': 'Split Squat (Langhantel)', // barbell split squat
  '2812': 'Step-up mit Split Squat (Kurzhantel)', // dumbbell step-up split squat
  '2963': "Beinheben gestreckt im Captain's Chair", // captain's chair straight leg raise
  '2987': 'Klimmzug eng im Untergriff mit Zusatzgewicht', // weighted close grip chin-up on dip cage
  '3006': 'Abduktion sitzend (Band)', // band seated hip abduction
  '3007': 'Beinstrecker (Band)', // band leg extension
  '3010': 'Überzüge mit gebeugten Armen liegend (SZ-Stange)', // ez bar lying bent arms pullover
  '3011': 'Schulterblatt-Liegestütz erhöht', // incline scapula push up
  '3012': 'Schulterblatt-Dips', // scapula dips
  '3013': 'Glute Bridge / Hüftheben', // low glute bridge on floor
  '3016': 'Curl-up (Bauch)', // curl-up
  '3017': 'Pendlay-Rudern (Langhantel)', // barbell pendlay row
  '3019': 'Rudern am Körpergewicht zwischen zwei Bänken', // bench inverted row
  '3021': 'Schulterblatt-Liegestütz', // scapula push-up
  '3116': 'Latziehen im Untergriff, verankert (Band)', // band anchored underhand pulldown
  '3117': 'Latziehen eng, verankert (Band)', // band anchored close grip pulldown
  '3119': 'Tiefe Hocke (Potty Squat)', // potty squat
  '3122': 'Schulterdrücken sitzend (Band)', // band seated shoulder press
  '3123': 'Bizepscurl sitzend (Band)', // band seated biceps curl
  '3124': 'Brustdrücken sitzend (Band)', // band seated chest press
  '3132': 'Tiefe Hocke mit Abstützen', // potty squat with support
  '3142': 'Sumo-Kniebeuge (Multipresse)', // smith sumo squat
  '3144': 'Rudern sitzend mit geradem Rücken (Band)', // band seated straight back row
  '3145': 'Liegestütz Plus', // push-up plus
  '3147': 'Beckenkippen', // pelvic tilt
  '3156': 'Rudern einarmig eng stehend am Körpergewicht', // bodyweight standing close-grip one arm row
  '3158': 'Rudern eng stehend am Körpergewicht', // bodyweight standing close-grip row
  '3161': 'Rudern einarmig stehend mit Handtuch', // bodyweight standing one arm row (with towel)
  '3162': 'Rudern einarmig stehend am Körpergewicht', // bodyweight standing one arm row
  '3165': 'Rudern stehend mit Handtuch', // bodyweight standing row (with towel)
  '3166': 'Rudern stehend am Körpergewicht', // bodyweight standing row
  '3167': 'Rudern in der Hocke mit Handtuch', // bodyweight squatting row (with towel)
  '3168': 'Rudern in der Hocke am Körpergewicht', // bodyweight squatting row
  '3193': 'Glute-Ham Raise', // glute-ham raise
  '3194': 'Frankenstein-Kniebeuge (Langhantel)', // frankenstein squat
  '3195': 'Beinbeuger beidbeinig hoch, einbeinig ab (Maschine)', // lever lying two-up one-down leg curl
  '3200': 'Rudern vorgebeugt mit V-Griff (Maschine)', // lever bent-over row with v-bar
  '3201': 'Sit-up Viertel', // quarter sit-up
  '3202': 'Sit-up halb', // half sit-up
  '3203': 'Sit-up halb mit Händen hinter dem Kopf', // prisoner half sit-up
  '3204': 'Sit-up mit Armen über Kopf', // arms overhead full sit-up
  '3211': 'Liegestütz auf den Knien', // kneeling push-up
  '3212': 'Zehen berühren', // toe touch
  '3213': 'Zehen berühren seitlich wechselnd', // side-to-side toe touch
  '3214': 'Zehen berühren mit Armkreisen grätschend', // arms apart circular toe touch
  '3215': 'Zehen berühren mit Armkreisen und Händen verschränkt umgekehrt', // hands reversed clasped circular toe touch
  '3216': 'Liegestütz mit Brusttippen', // chest tap push-up
  '3217': 'Hindu-Liegestütz modifiziert', // modified hindu push-up
  '3218': 'Zehen berühren mit Armkreisen und Händen verschränkt', // hands clasped circular toe touch
  '3219': 'Scherensprung', // scissor jumps
  '3220': 'Grätschsprung', // astride jumps
  '3221': 'Halbe Kniebeuge', // half knee bends
  '3222': 'Halbe Sprungkniebeuge', // semi squat jump
  '3223': 'Sternsprung', // star jump
  '3224': 'Hampelmann', // jumping jack
  '3231': 'Zehen berühren beidhändig', // two toe touch
  '3234': 'Fliegende hoch (Kurzhantel)', // dumbbell high fly
  '3235': 'Nordic Curl mit Kabelzug-Unterstützung (Kabelzug)', // cable assisted inverse leg curl
  '3236': 'Hip Thrust kniend (Band)', // band kneeling hip thrust
  '3237': 'Seitheben (Landmine)', // landmine lateral raise
  '3239': 'Unterarmstütz kniend mit Schultertippen', // kneeling plank shoulder tap
  '3240': 'Wadenheben an der Wand mit Ball zwischen den Knien (Kurzhantel)', // exercise ball wall calf raise (ball between knees)
  '3241': 'Wadenheben an der Wand mit Ball zwischen den Knöcheln (Kurzhantel)', // exercise ball wall calf raise (ball between ankles)
  '3281': 'Kniebeuge tief (Multipresse)', // smith full squat
  '3286': 'Muscle-up mit Zusatzgewicht', // weighted muscle up
  '3287': 'Ellbogen-Dips', // elbow dips
  '3288': 'Korean Dips', // korean dips
  '3289': 'Impossible Dips', // impossible dips
  '3290': 'Klimmzug einarmig mit Zusatzgewicht', // weighted one hand pull up
  '3291': 'Stalder Press', // stalder press
  '3292': 'Elevator (Rumpfbeuge)', // elevator
  '3293': 'Archer-Klimmzug', // archer pull up
  '3294': 'Archer-Liegestütz', // archer push up
  '3295': 'Front-Lever-Wiederholungen', // front lever reps
  '3296': 'Front Lever', // front lever
  '3297': 'Back Lever', // back lever
  '3298': 'Straddle Planche', // straddle planche
  '3299': 'Full Planche', // full planche
  '3300': 'Lean Planche', // lean planche
  '3301': 'Frog Planche', // frog planche
  '3302': 'Handstand', // handstand
  '3303': 'Human Flag', // flag
  '3304': 'Skin the Cat', // skin the cat
  '3305': 'Thruster (Langhantel)', // barbell thruster
  '3312': 'Muscle-up an der Stange mit Zusatzgewicht', // weighted muscle up (on bar)
  '3313': 'Dips an der geraden Stange mit Zusatzgewicht', // weighted straight bar dip
  '3314': 'Straddle Maltese', // straddle maltese
  '3315': 'Full Maltese', // full maltese
  '3318': 'Armschwung 360°', // swing 360
  '3327': 'Full-Planche-Liegestütz', // full planche push-up
  '3360': 'Bärengang (Bear Crawl)', // bear crawl
  '3361': 'Eisschnellläufer-Sprünge (Skater Hops)', // skater hops
  '3418': 'L-Klimmzug', // l-pull-up
  '3419': 'L-Sitz am Boden', // l-sit on floor
  '3420': 'V-Sitz am Boden', // v-sit on floor
  '3433': 'Swimmer Kicks (Bauchlage)', // swimmer kicks
  '3470': 'Ausfallschritt vorwärts', // forward lunge
  '3523': 'Glute Bridge mit Füßen auf der Bank', // glute bridge (feet on bench)
  '3533': 'Kniebeuge (Körpergewicht)', // bodyweight squat
  '3541': 'Y-Heben auf der Schrägbank (Kurzhantel)', // dumbbell incline y-raise
  '3542': 'T-Heben auf der Schrägbank (Kurzhantel)', // dumbbell incline t-raise
  '3543': 'Drop Jump in die Kniebeuge', // bodyweight drop jump squat
  '3544': 'Seitstütz erhöht', // bodyweight incline side plank
  '3545': 'Schrägbankdrücken abwechselnd (Kurzhantel)', // dumbbell incline alternate press
  '3546': 'Schulterdrücken abwechselnd sitzend (Kurzhantel, Variante 2)', // dumbbell seated alternate shoulder press
  '3547': 'Bizepscurl mit Schulterdrücken sitzend (Kurzhantel)', // dumbbell seated biceps curl to shoulder press
  '3548': 'Überkopf-Tragen einarmig (Kurzhantel)', // dumbbell single arm overhead carry
  '3552': 'Quick Feet / Schnelle Füße', // quick feet
  '3560': 'Hammercurl mit Schulterdrücken abwechselnd stehend (Kurzhantel)', // dumbbell standing alternate hammer curl and press
  '3561': 'Glute Bridge mit Marschieren', // glute bridge march
  '3562': 'Glute Bridge mit Füßen auf der Bank (Langhantel)', // barbell glute bridge (feet on bench)
  '3563': 'Latziehen einarmig (Kabelzug)', // cable one arm pulldown
  '3582': 'Ausfallschritt mit Sprung', // lunge with jump
  '3635': 'Ausfallschritt vorwärts kontralateral (Kurzhantel)', // dumbbell contralateral forward lunge
  '3636': 'Knieheben an der Wand', // high knee against wall
  '3637': 'Bauchroller-Lauf', // ab wheel run
  '3638': 'Liegestütz mit Sprintstart', // push-up to run
  '3639': 'Knie-Rumpfdrehung liegend', // bent knee lying twist
  '3640': 'Crunch mit Knietippen', // knee touch crunch
  '3641': 'Kniender Ausfallschritt mit Gewichtsschwung', // weighted kneeling step with swing
  '3642': 'Ausfallschritt mit Dehnung und Gewicht', // weighted stretch lunge
  '3643': 'Cossack Squat mit Gewicht', // weighted cossack squat
  '3644': 'Ausfallschritt mit Gewichtsschwung', // weighted lunge with swing
  '3645': 'Glute Bridge einbeinig mit gestrecktem Bein', // single leg bridge with outstretched leg
  '3655': 'Ausfallschritt gehend mit Knieheben', // walking high knees lunge
  '3656': 'Laufen mit kurzen Schritten', // short stride run
  '3662': 'Pike-zu-Kobra-Liegestütz', // pike-to-cobra push-up
  '3663': 'Unterarmstütz rücklings mit Beinheben', // reverse plank with leg lift
  '3664': 'Seitstütz mit Reverse Fly (Kurzhantel)', // dumbbell side plank with rear fly
  '3665': 'Unterarmstütz Power Point', // power point plank
  '3666': 'Gehen auf dem Laufband (Steigung)', // walking on incline treadmill
  '3667': 'Adduktion seitlich liegend', // side lying hip adduction
  '3669': 'Archer-Dehnung stehend', // standing archer
  '3670': 'Sit-up auf der Negativbank mit Gewicht', // weighted decline sit-up
  '3671': 'Skisprünge seitlich', // ski step
  '3672': 'Ausfallschritt vor und zurück', // back and forth step
  '3679': 'Sit-up mit Armen vor der Brust', // sit-up with arms on chest
  '3697': 'Face Pull kniend (Kabelzug, Seil)', // cable kneeling rear delt row (with rope)
  '3698': 'Inchworm / Raupe (Variante 2)', // inchworm v. 2
  '3699': 'Schultertippen im Stütz', // shoulder tap
  '3758': 'Brustpresse stehend (Maschine)', // lever standing chest press
  '3759': 'Good Morning sitzend (Maschine)', // lever seated good morning
  '3760': 'Crunch sitzend (Maschine, Variante 2)', // lever seated crunch v. 2
  '3769': 'Curtsy Lunge / Knicks-Ausfallschritt', // curtsy squat
  '3785': 'Liegestütz erhöht (Hände auf Box)', // incline push-up (on box)
  '3888': 'Reißen einarmig (Kurzhantel)', // dumbbell one arm snatch
  '5201': 'Kellner-Bizepscurl (Kurzhantel)', // dumbbell waiter biceps curl
};

/// The classic, most searched exercises (all exercises of the built-in programs plus the
/// usual gym, home and bodyweight lifts) – ranked before rarer variants in the search.
const popularExerciseIds = {
  // the curated names before the complete table
  '0025', '0289', '0748', '0151', '1254', '0122', '0030', '0047', '0314', '0757', '0169', '0033', '0753', '0577', '0308', '0319',
  '0302', '0227', '0179', '0188', '0171', '0596', '0662', '0493', '0279', '0283', '0259', '0659', '0251', '0375', '0073', '0652',
  '1429', '0017', '0970', '0841', '0688', '1326', '1327', '0572', '2330', '0198', '0245', '0579', '0238', '0027', '3017', '0293',
  '0861', '1350', '0606', '0581', '0499', '0808', '0032', '0300', '0811', '0117', '0085', '1459', '0432', '1757', '1756', '0489',
  '0573', '0044', '0095', '0406', '0604', '0203', '0426', '0405', '0091', '1457', '0603', '0997', '2137', '0334', '0178', '0978',
  '0162', '0041', '0378', '0993', '0120', '0246', '0471', '0031', '0447', '0294', '0285', '0313', '0318', '0297', '0070', '0372',
  '0868', '0575', '0241', '0201', '0207', '0194', '0061', '0060', '2188', '0333', '0607', '0814', '0129', '1399', '0126', '2133',
  '0043', '0042', '0413', '0770', '1760', '0534', '0743', '0046', '0514', '1004', '1489', '2368', '0410', '0739', '0760', '0585',
  '0586', '0599', '0336', '0054', '0381', '0078', '1460', '0431', '0114', '1409', '3013', '3561', '0597', '0598', '0860', '0605',
  '0594', '0409', '1373', '0284', '3193', '0274', '0872', '0277', '0212', '0832', '0262', '0003', '0472', '0689', '0687', '0846',
  '0276', '2135', '0464', '3544', '0705', '0282', '0001', '0630', '0243', '1160', '0549', '3305', '0648', '2612',
};

/// Corrected English names of database entries whose original name was broken (typos,
/// "v. 2", "(male)", camera angles …). The database carries the corrected name; this map
/// also fixes the name stored in older sessions and programs.
const exerciseNamesEn = <String, String>{
  '0020': 'balance board stand',
  '0048': 'barbell incline reverse-grip bench press',
  '0079': 'barbell reverse wrist curl v. 2',
  '0083': 'barbell rollout from bench',
  '0084': 'barbell rollout',
  '0096': 'barbell side bend',
  '0103': 'barbell standing ab rollout',
  '0154': 'cable cross-over reverse fly',
  '0186': 'cable lying triceps extension',
  '0191': 'cable one arm bent-over fly',
  '0199': 'cable straight arm pulldown (standing)',
  '0316': 'dumbbell incline twisting fly',
  '0339': 'dumbbell lying leg curl',
  '0368': 'dumbbell over bench reverse wrist curl',
  '0370': 'dumbbell preacher hammer curl',
  '0377': 'dumbbell rear delt row',
  '0382': 'dumbbell reverse grip biceps curl',
  '0403': 'dumbbell seated reverse grip concentration curl',
  '0445': 'ez barbell anti-gravity press',
  '0496': 'nordic hamstring curl (bench support)',
  '0543': 'kettlebell pirate ships',
  '0574': 'landmine bent over row',
  '0589': 'landmine one arm row',
  '0613': 'side lying quad stretch',
  '0624': 'wall sit march',
  '0696': 'nordic hamstring curl (on floor)',
  '0697': 'nordic hamstring curl',
  '0705': 'side bridge',
  '0754': 'smith decline reverse-grip bench press',
  '0758': 'smith incline reverse-grip bench press',
  '0764': 'smith reverse-grip bench press',
  '0796': 'standing ab wheel rollout',
  '0857': 'ab wheel rollout',
  '0859': 'wrist roller',
  '0869': 'lever shoulder press (variation 2)',
  '0971': 'band assisted ab wheel rollout',
  '1167': 'dynamic chest stretch',
  '1307': 'push-up on bosu ball (flat side up)',
  '1355': 'one arm lat stretch against wall',
  '1369': 'band two legs calf raise (band under both feet)',
  '1380': 'dumbbell seated one leg calf raise (hammer grip)',
  '1381': 'dumbbell seated one leg calf raise (palm up)',
  '1382': 'exercise ball wall calf raise',
  '1390': 'seated calf stretch',
  '1397': 'standing calf raise (floor)',
  '1398': 'standing calf stretch',
  '1418': 'hug knees to chest',
  '1495': 'oblique crunch',
  '1496': 'sledgehammer strikes',
  '1512': 'all fours quad stretch',
  '1585': "runner's stretch",
  '1604': "world's greatest stretch",
  '1759': 'pistol squat',
  '1772': 'elbow lift (reverse push-up)',
  '2133': "farmer's walk",
  '2139': 'arm ergometer',
  '2143': 'dumbbell standing around the world',
  '2203': 'roller seated shoulder mobilization',
  '2209': 'roller seated single leg shoulder mobilization',
  '2271': 'left hook (boxing)',
  '2286': 'lever hip extension',
  '2288': 'lever hand gripper',
  '2318': 'lever shoulder press (variation 3)',
  '2321': 'dumbbell standing inner biceps curl',
  '2327': 'dumbbell reverse grip row',
  '2799': 'barbell seated alternate leg raise',
  '2800': 'barbell seated alternate leg raise (variation 2)',
  '2801': 'twisted leg raise (variation 2)',
  '2810': 'barbell split squat',
  '2963': "captain's chair straight leg raise",
  '3006': 'band seated hip abduction',
  '3007': 'band leg extension',
  '3019': 'bench inverted row',
  '3116': 'band anchored underhand pulldown',
  '3117': 'band anchored close grip pulldown',
  '3122': 'band seated shoulder press',
  '3123': 'band seated biceps curl',
  '3124': 'band seated chest press',
  '3144': 'band seated straight back row',
  '3195': 'lever lying two-up one-down leg curl',
  '3202': 'half sit-up',
  '3203': 'prisoner half sit-up',
  '3204': 'arms overhead full sit-up',
  '3211': 'kneeling push-up',
  '3212': 'toe touch',
  '3213': 'side-to-side toe touch',
  '3214': 'arms apart circular toe touch',
  '3215': 'hands reversed clasped circular toe touch',
  '3216': 'chest tap push-up',
  '3217': 'modified hindu push-up',
  '3218': 'hands clasped circular toe touch',
  '3219': 'scissor jumps',
  '3220': 'astride jumps',
  '3221': 'half knee bends',
  '3222': 'semi squat jump',
  '3223': 'star jump',
  '3224': 'jumping jack',
  '3231': 'two toe touch',
  '3234': 'dumbbell high fly',
  '3236': 'band kneeling hip thrust',
  '3239': 'kneeling plank shoulder tap',
  '3240': 'exercise ball wall calf raise (ball between knees)',
  '3241': 'exercise ball wall calf raise (ball between ankles)',
  '3433': 'swimmer kicks',
  '3470': 'forward lunge',
  '3523': 'glute bridge (feet on bench)',
  '3533': 'bodyweight squat',
  '3546': 'dumbbell seated alternate shoulder press',
  '3552': 'quick feet',
  '3562': 'barbell glute bridge (feet on bench)',
  '3637': 'ab wheel run',
  '3638': 'push-up to run',
  '3639': 'bent knee lying twist',
  '3643': 'weighted cossack squat',
  '3667': 'side lying hip adduction',
  '3697': 'cable kneeling rear delt row (with rope)',
  '3769': 'curtsy squat',
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
/// German name (every database exercise has one), else a cached translation, else a
/// rule-based German name of the database name ([germanExerciseName]) – never the raw
/// English one (also for stored sessions). English: the corrected name of a broken database
/// entry ([exerciseNamesEn]), else [en].
String exerciseName(String id, String en, String lang) {
  if (lang == 'de') {
    final de = exerciseNamesDe[id] ?? exerciseNamePrefs?.getString('trn_de_$id');
    if (de != null && de.trim().isNotEmpty) return de.replaceFirst(_leadingSeparators, '');
    // A name the user typed (custom exercise) or an already German name stays as it is.
    if (en.isNotEmpty && !_looksGerman(en)) return germanExerciseName(en);
  }
  final name = exerciseNamesEn[id] ?? en;
  return name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}

final _leadingSeparators = RegExp(r'^[\s\-–·:]+');
final _germanWords = RegExp('[äöüß]|drücken|heben|beuge|rudern|ziehen', caseSensitive: false);

bool _looksGerman(String s) => _germanWords.hasMatch(s);

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
  ('close grip', 'eng'),
  ('close-grip', 'eng'),
  ('narrow grip', 'eng'),
  ('wide grip', 'breit'),
  ('wide-grip', 'breit'),
  ('reverse grip', 'Untergriff'),
  ('reverse-grip', 'Untergriff'),
  ('underhand', 'Untergriff'),
  ('overhand', 'Obergriff'),
  ('palms up', 'Untergriff'),
  ('palms down', 'Obergriff'),
  ('neutral grip', 'Neutralgriff'),
  ('neutral-grip', 'Neutralgriff'),
  ('parallel grip', 'Neutralgriff'),
  ('hammer grip', 'Hammergriff'),
  ('mixed grip', 'Kreuzgriff'),
  ('one arm', 'einarmig'),
  ('one-arm', 'einarmig'),
  ('single arm', 'einarmig'),
  ('single-arm', 'einarmig'),
  ('one leg', 'einbeinig'),
  ('one-leg', 'einbeinig'),
  ('single leg', 'einbeinig'),
  ('single-leg', 'einbeinig'),
  ('two arm', 'beidarmig'),
  ('straight arm', 'mit gestreckten Armen'),
  ('straight leg', 'mit gestreckten Beinen'),
  ('bent over', 'vorgebeugt'),
  ('bent-over', 'vorgebeugt'),
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
  ('incline', 'auf der Schrägbank'),
  ('decline', 'auf der Negativbank'),
  ('weighted', 'mit Gewicht'),
  ('assisted', 'unterstützt'),
  ('overhead', 'über Kopf'),
  ('reverse', 'umgekehrt'),
  ('high', 'hoch'),
  ('low', 'tief'),
];

const _fillerWords = {
  'with',
  'on',
  'the',
  'to',
  'and',
  'a',
  'of',
  'v',
  'male',
  'female',
  'pov',
  'version',
  'exercise',
  'body',
  'weight',
  'bodyweight',
};

/// Rule-based German name of an English database name for exercises without a curated or
/// translated name: the movement first, then the variation, the equipment in brackets
/// ("dumbbell seated shoulder press" → "Schulterdrücken sitzend (Kurzhantel)"). Words it
/// does not know (proper names like "Zottman") are kept in front of the movement.
///
/// Memoised: the rules run ~100 regular expressions per name, and lists sort / filter the
/// whole library (1300+ names) by it – recomputing them made the exercise library stall.
String germanExerciseName(String en) => _germanNames[en] ??= _germanExerciseName(en);

final _germanNames = <String, String>{};

/// The compiled whole-word pattern of each table phrase (compiled once, not per name).
final _phraseRes = <String, RegExp>{};
final _brackets = RegExp(r'\(.*?\)|v\.\s*\d|\bv\d\b');
final _spaces = RegExp(r'\s+');
final _number = RegExp(r'^\d+$');
final _letterOrDigit = RegExp('[a-z0-9äöüß]');

String _germanExerciseName(String en) {
  var s = ' ${en.toLowerCase().replaceAll(_brackets, ' ').replaceAll(_spaces, ' ').trim()} ';
  String? take(List<(String, String)> table) {
    for (final (k, v) in table) {
      if (!s.contains(k)) continue; // cheap pre-check: the pattern needs the phrase itself
      // Hyphenated words only match as a whole ("reverse-grip" is no "reverse" + "-grip").
      final re = _phraseRes[k] ??= RegExp('(?<![a-z-])${RegExp.escape(k)}s?(?![a-z-])');
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
    for (final w in s.trim().split(_spaces))
      // Separators of the database names ("calf raise - hammer grip") are no words: never a
      // leading "- Hammer Grip Wadenheben".
      if (w.isNotEmpty && !_fillerWords.contains(w) && !_number.hasMatch(w) && _letterOrDigit.hasMatch(w))
        w[0].toUpperCase() + w.substring(1),
  ];
  // Nothing but equipment / variations understood: no German name ("(Langhantel)" alone).
  if (movement == null && rest.isEmpty) return en.isEmpty ? en : en[0].toUpperCase() + en.substring(1);
  final head = [...rest, movement ?? ''].where((x) => x.isNotEmpty).join(' ');
  final name = [head.isEmpty ? (equipment ?? '') : head, ...mods].join(' ');
  return equipment == null || head.isEmpty ? name : '$name ($equipment)';
}

/// [exerciseName] in the language of [context].
String exName(BuildContext context, String id, String en) => exerciseName(id, en, Localizations.localeOf(context).languageCode);
