class HiveCellCategory {
  const HiveCellCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.styleKey,
    this.featured = false,
  });

  final String id;
  final String name;
  final String description;
  final String styleKey;
  final bool featured;
}

const List<HiveCellCategory> hiveTopLevelCategories = [
  HiveCellCategory(
    id: 'people',
    name: 'People',
    description: 'Portraits, selfies, and shared moments',
    styleKey: 'people',
    featured: true,
  ),
  HiveCellCategory(
    id: 'family',
    name: 'Family',
    description: 'The people you return to most',
    styleKey: 'family',
    featured: true,
  ),
  HiveCellCategory(
    id: 'pets',
    name: 'Pets',
    description: 'Warm moments and familiar faces',
    styleKey: 'pets',
    featured: true,
  ),
  HiveCellCategory(
    id: 'travel',
    name: 'Travel',
    description: 'Trips, weekends, and new places',
    styleKey: 'travel',
  ),
  HiveCellCategory(
    id: 'places',
    name: 'Places',
    description: 'Scenery, venues, skylines, and memorable locations',
    styleKey: 'places',
  ),
  HiveCellCategory(
    id: 'food',
    name: 'Food',
    description: 'Meals, drinks, and dishes worth remembering',
    styleKey: 'food',
  ),
  HiveCellCategory(
    id: 'videos',
    name: 'Videos',
    description: 'Clips, motion moments, and moving memories',
    styleKey: 'videos',
  ),
  HiveCellCategory(
    id: 'screenshots',
    name: 'Screenshots',
    description: 'Captured references and saved screens',
    styleKey: 'screenshots',
  ),
  HiveCellCategory(
    id: 'devices_tech',
    name: 'Devices / Tech',
    description: 'Gadgets, desks, and digital gear',
    styleKey: 'tech',
  ),
  HiveCellCategory(
    id: 'documents_receipts',
    name: 'Documents / Receipts',
    description: 'Paperwork and references worth keeping',
    styleKey: 'documents',
  ),
  HiveCellCategory(
    id: 'sports',
    name: 'Sports',
    description: 'Games, training, and active moments',
    styleKey: 'sports',
    featured: true,
  ),
  HiveCellCategory(
    id: 'animation_cartoon_meme',
    name: 'Animation / Cartoon / Meme',
    description: 'Stylized art, saved jokes, and internet moments',
    styleKey: 'animation',
    featured: true,
  ),
  HiveCellCategory(
    id: 'unsorted',
    name: 'Unsorted',
    description: 'Assets that still need a stronger signal',
    styleKey: 'unsorted',
  ),
];
