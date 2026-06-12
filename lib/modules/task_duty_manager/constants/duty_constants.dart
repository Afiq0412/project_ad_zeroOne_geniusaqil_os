/// Central source of truth for all duty types, zones, time slots,
/// checklists, and configuration constants used throughout the
/// Task & Duty Manager module.
class DutyConstants {
  // ─── Duty Type Keys ──────────────────────────────────────────
  static const String cleaning    = 'Cleaning';
  static const String arrival     = 'Arrival';
  static const String dismissal   = 'Dismissal';
  static const String halfFullDay = 'HalfFullDay';
  static const String assembly    = 'Assembly';

  static const List<String> allDutyTypes = [
    cleaning, arrival, dismissal, halfFullDay, assembly,
  ];

  // ─── Display Names ───────────────────────────────────────────
  static const Map<String, String> dutyDisplayNames = {
    cleaning:    'Cleaning Duty',
    arrival:     'Arrival Duty',
    dismissal:   'Dismissal Duty',
    halfFullDay: 'Half-Full Day Transition Duty',
    assembly:    'Assembly Duty',
  };

  // ─── Time Slots ──────────────────────────────────────────────
  static const Map<String, String> timeSlots = {
    cleaning:    '4:30 – 5:00 PM',
    arrival:     '7:30 – 8:00 AM',
    dismissal:   '12:00 – 12:30 PM / 5:00 – 5:15 PM',
    halfFullDay: '12:00 – 2:30 PM',
    assembly:    'Every Monday',
  };

  // ─── Frequency ───────────────────────────────────────────────
  static const Map<String, String> frequency = {
    cleaning:    'Daily (Mon–Fri)',
    arrival:     'Daily (Mon–Fri)',
    dismissal:   'Daily (Mon–Fri)',
    halfFullDay: 'Daily (Mon–Fri)',
    assembly:    'Weekly (Monday)',
  };

  // ─── Weekdays ────────────────────────────────────────────────
  static const List<String> weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
  ];

  // ─── Zones per Duty Type ─────────────────────────────────────
  static const Map<String, List<String>> zones = {
    cleaning:    ['Assembly Hall', 'Dining Area', 'Nap Room & Stairs', 'Toilet'],
    arrival:     ['Main Door', 'Stairs', 'Hall 1st Floor', 'Hall 2nd Floor'],
    dismissal:   ['Main Door', 'Stairs', 'Shoes Rack'],
    halfFullDay: [
      'Full Day (Boy)',
      'Full Day (Girl)',
      'Full Day (6 Years Old)',
      'Hall and Cooking the Rice',
    ],
    // For Assembly: 'Sub Theme' stores the theme text (not a teacher ID).
    // All other slots store teacher UIDs.
    assembly: [
      'Sub Theme',
      'Introduction',
      'Song',
      'Islamic Content',
      'Words of the Week & Sight Words',
    ],
  };

  /// The 'Sub Theme' slot in Assembly duty holds theme text, not a teacher UID.
  static const String assemblySubThemeKey = 'Sub Theme';

  // ─── Max Teachers per Zone ───────────────────────────────────
  // Dining Area allows 2 teachers; all other zones use 1.
  static int getMaxTeachers(String zone) =>
      zone == 'Dining Area' ? 2 : 1;

  // ─── Duty Emoji Icons ────────────────────────────────────────
  static const Map<String, String> dutyIcons = {
    cleaning:    '🧹',
    arrival:     '🌅',
    dismissal:   '🚪',
    halfFullDay: '🍱',
    assembly:    '🎤',
  };

  // ─── Duty Colour Accents (hex strings used for display) ──────
  static const Map<String, int> dutyColors = {
    cleaning:    0xFF1565C0, // deep blue
    arrival:     0xFF2E7D32, // deep green
    dismissal:   0xFFE65100, // deep orange
    halfFullDay: 0xFF6A1B9A, // deep purple
    assembly:    0xFF00838F, // teal
  };

  // ─── Checklist Items (Cleaning Duty zones only) ───────────────
  // Other duty types use a single "Mark as Done" toggle.
  static const Map<String, List<String>> checklistItems = {
    'Assembly Hall': [
      'Sweep the assembly hall floor',
      'Mop the assembly hall floor',
      "Arrange chair and table at teacher's corner neatly",
      'Clean the tables at assembly hall',
      'Empty dustbins',
      'Arrange mic and audio equipment properly',
      'Clean and rearrange toys at Play Area',
      'Clean the trolleys at the assembly hall',
      'Switch off all lights and air conditioners',
    ],
    'Dining Area': [
      'Sweep the dining area floor',
      'Mop the dining area floor',
      'Wipe and sanitize dining tables',
      'Arrange chairs neatly',
      'Empty the dirty dishes trolley',
      "Clean and empty main and students' sinks",
      "Wipe student's mirror",
      'Wash and dry the cleaning cloths',
      'Refill hand and dish soap',
      'Empty rubbish bin',
    ],
    'Nap Room & Stairs': [
      "Fold student's blanket neatly",
      "Place the student's blanket and pillow into their bags",
      'Store the mattresses neatly in the storeroom',
      'Sweep the stairs area',
      'Mop the stairs carefully',
      'Wipe stair handrails clean',
      'Arrange shoes neatly if any',
    ],
    'Toilet': [
      'Flush all toilets properly',
      'Clean toilet bowls thoroughly',
      'Scrub and disinfect the toilet floor',
      'Refill hand soap',
      'Clean toilet doors',
      'Ensure buckets and cleaning tools are arranged neatly',
      'Arrange the slippers neatly',
      'Ensure there are no items left on the floor',
    ],
  };

  /// Returns true if this duty type + zone combination has a
  /// detailed item-level checklist (currently only Cleaning Duty).
  static bool hasChecklist(String dutyType, String zone) {
    return dutyType == cleaning && checklistItems.containsKey(zone);
  }

  /// Returns the checklist items for a given zone, or empty list.
  static List<String> getChecklistItems(String zone) {
    return checklistItems[zone] ?? [];
  }

  /// Returns the display name for a duty type, falling back to the key.
  static String displayName(String dutyType) =>
      dutyDisplayNames[dutyType] ?? dutyType;

  /// Returns the emoji icon for a duty type.
  static String icon(String dutyType) => dutyIcons[dutyType] ?? '📋';

  /// Returns the time slot string for a duty type.
  static String timeSlot(String dutyType) => timeSlots[dutyType] ?? '';

  /// Returns the zones list for a duty type.
  static List<String> zonesFor(String dutyType) => zones[dutyType] ?? [];
}
