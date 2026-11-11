{
    # H3 – "Nur Planlänge" with a race goal
    'summaryRemoveRaceGoal': ['Remove the race goal “{name}” ({date})', 'Wettkampfziel „{name}“ ({date}) entfernen'],
    'summaryRemoveRaceGoalOn': [
        'Your new plan has no race – the goal the previous plan was built for is removed with it.',
        'Dein neuer Plan hat keinen Wettkampf – das Ziel, auf das der bisherige Plan ausgerichtet war, wird entfernt.',
    ],
    'summaryRemoveRaceGoalOff': [
        'The goal stays: its countdown and the hint “Goal and plan don’t match” remain until you align a plan with it again.',
        'Das Ziel bleibt: Countdown und der Hinweis „Ziel und Plan passen nicht zusammen“ bleiben, bis du einen Plan wieder darauf ausrichtest.',
    ],
    # L6
    'fcEarlyMore': [
        '{count, plural, =1{One more workout of the plan and the forecast uses your training data.} other{{count} more workouts of the plan and the forecast uses your training data.}}',
        '{count, plural, =1{Nach einer weiteren Einheit des Plans nutzt die Prognose deine Trainingsdaten.} other{Nach {count} weiteren Einheiten des Plans nutzt die Prognose deine Trainingsdaten.}}',
    ],
    # M3
    'plannedNotCountedSub': [
        'Your session on {date} ({duration}) was too short to count for this workout – it stays open.',
        'Deine Einheit am {date} ({duration}) war zu kurz, um für diese Einheit zu zählen – sie bleibt offen.',
    ],
    # M4 – the bucket labels
    'overPlanShort': ['above plan ({share})', 'über Plan ({share})'],
    'farOffShort': ['far off plan ({share})', 'stark abweichend ({share})'],
    'termComplianceBody': [
        'Compared with the plan is the distance (endurance workouts with a distance; structured workouts: distance or duration, whichever is closer to the plan), the done work sets (strength – sets done at a much lighter weight or with far fewer reps count partly) or else the duration. A workout marked as done with the plan\'s numbers counts as planned.\n\n✓ green, as planned: {greenMin}–{greenMax}\n✓ yellow, partly / above plan: {yellowMin} to under {greenMin}, or over {greenMax} up to {yellowMax}\n✓ orange, far off: {countMin} to under {yellowMin}, or over {yellowMax}\n✕ red: missed, or under {countMin} – an aborted start doesn’t count as done.',
        'Mit dem Plan verglichen wird die Strecke (Ausdauer mit Distanz; strukturierte Einheiten: Strecke oder Dauer, je nachdem, was näher am Plan liegt), die erledigten Arbeitssätze (Kraft – Sätze mit deutlich weniger Gewicht oder Wiederholungen zählen teilweise) oder sonst die Dauer. Eine mit den Planwerten als erledigt eingetragene Einheit zählt wie geplant.\n\n✓ grün, wie geplant: {greenMin}–{greenMax}\n✓ gelb, teilweise / über Plan: {yellowMin} bis unter {greenMin} oder über {greenMax} bis {yellowMax}\n✓ orange, stark abweichend: {countMin} bis unter {yellowMin} oder über {yellowMax}\n✕ rot: verpasst, oder unter {countMin} – ein abgebrochener Start zählt nicht als erledigt.',
    ],
    'termComplianceTip': [
        'Partly or far off still counts as done – the plan only adapts when it happens repeatedly. For that, a long run or a key session needs at least {half} of the plan, and clearly more than planned (over {over}) counts like a session that was too hard.',
        'Teilweise oder stark abweichend zählt trotzdem als erledigt – der Plan passt sich erst an, wenn es sich wiederholt. Dafür braucht ein langer Lauf oder eine Schlüsseleinheit mindestens {half} des Plans, und deutlich mehr als geplant (über {over}) zählt wie eine zu harte Einheit.',
    ],
    # H4
    'logCompletesPlanOf': ['Completes the workout planned for {day}', 'Zählt für die Einheit vom {day}'],
    # M11
    'invalidNumber': ['Please enter a number', 'Bitte eine Zahl eingeben'],
    'withoutDistance': ['Without distance', 'Ohne Distanz'],
    'enterDistanceHint': ['e.g. from the treadmill', 'z. B. vom Laufband'],
    # L14
    'streakThisWeekShort': ['This week: {done} of {target} training days', 'Diese Woche: {done} von {target} Trainingstagen'],
    # L10 – "KG" read as kilograms
    'bodyweightShort': ['BW', 'Körpergew.'],
    # L11
    'freeGymTitle': ['Free workout', 'Freies Training'],
    # L3
    'sessionEndsInFuture': [
        'With this start and duration the workout would end in the future ({time}) – please check both.',
        'Mit diesem Start und dieser Dauer würde die Einheit in der Zukunft enden ({time}) – bitte prüfe beides.',
    ],
    'sessionPaceImplausible': [
        'Average {pace} – hardly possible. Are the distance and duration right?',
        'Durchschnitt {pace} – kaum möglich. Stimmen Distanz und Dauer?',
    ],
    # L7
    'recNow': ['now {count}×', 'jetzt {count}×'],
    # M8 – swim test feedback
    'yourSwimZones': ['Your swim zones', 'Deine Schwimmzonen'],
    'swimCssEstimated': [
        'Estimated from your 400 m – add the 200 m for an exact CSS.',
        'Geschätzt aus deinen 400 m – mit der 200-m-Zeit wird die CSS genau.',
    ],
    'swimTestOnly200': [
        'The CSS test needs the 400 m time too – the 200 m alone is not enough.',
        'Für den CSS-Test brauchst du auch die 400-m-Zeit – die 200 m allein reichen nicht.',
    ],
    'swimTestImplausible': [
        'These two times don’t fit together (the 400 m should take a little more than twice the 200 m). Please check them – until then the CSS is estimated from the 400 m.',
        'Die beiden Zeiten passen nicht zusammen (die 400 m dauern etwas mehr als doppelt so lange wie die 200 m). Bitte prüfe sie – bis dahin wird die CSS aus den 400 m geschätzt.',
    ],
    # L4
    'planLengthHint': ['Recommended for your goal: {lo}–{hi} weeks.', 'Empfohlen für dein Ziel: {lo}–{hi} Wochen.'],
    # M12
    'generatePlanSub': [
        'Focus: {focus} · {days} days/week (change in plan settings)',
        'Fokus: {focus} · {days} Tage/Woche (in den Planeinstellungen änderbar)',
    ],
    'feasLongDayDefault': [
        'The long session on {day} needs up to {time} – far more than your other sessions. The plan schedules it like that; set that day’s time yourself if it does not fit.',
        'Die lange Einheit am {day} braucht bis zu {time} – deutlich mehr als deine übrigen Einheiten. Der Plan plant sie so ein; trag die Zeit für diesen Tag selbst ein, falls sie nicht passt.',
    ],
}
