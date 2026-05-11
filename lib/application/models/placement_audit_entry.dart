import 'asset_mapping_explanation.dart';

class PlacementAuditEntry {
  const PlacementAuditEntry({
    required this.assetId,
    required this.finalCell,
    required this.routeLayer,
    required this.topScores,
    required this.firedVetoes,
    required this.firedGates,
    required this.isNaturalPhoto,
    required this.humanPresenceScore,
    required this.animalPresenceScore,
    required this.graphicnessScore,
    required this.documentnessScore,
    required this.sceneDensityScore,
    required this.timestamp,
    this.unsortedReason,
  });

  final String assetId;
  final String finalCell;
  final String routeLayer;
  final Map<String, double> topScores;
  final List<String> firedVetoes;
  final List<String> firedGates;
  final UnsortedReason? unsortedReason;
  final bool isNaturalPhoto;
  final double humanPresenceScore;
  final double animalPresenceScore;
  final double graphicnessScore;
  final double documentnessScore;
  final double sceneDensityScore;
  final DateTime timestamp;
}
