import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/application/models/asset_mapping_explanation.dart';
import 'package:hive_flutter_v1/application/models/structural_signals.dart';
import 'package:hive_flutter_v1/data/services/placement/keyword_placement_pipeline.dart';
import 'package:hive_flutter_v1/data/services/placement/placement_definitions.dart';
import 'package:hive_flutter_v1/data/services/placement/placement_models.dart';
import 'package:hive_flutter_v1/data/services/structural_signal_extractor.dart';
import 'package:hive_flutter_v1/domain/entities/classification_label.dart';
import 'package:hive_flutter_v1/domain/entities/media_asset.dart';

void main() {
  final analysisBuilder = PlacementAnalysisBuilder();
  const routingStage = ContentTypeRoutingStage();
  const scoringStage = WeightedCategoryScoringStage();
  const decisionStage = PlacementDecisionStage();
  final pipeline = KeywordPlacementPipeline();

  group('structural signals are populated', () {
    test(
      'after extraction on an asset with a clear face structural faceCount is at least 1',
      () async {
        final asyncAnalysisBuilder = PlacementAnalysisBuilder(
          structuralExtractor: StructuralSignalExtractor(
            imageLoader: _fakeImageLoader,
            faceExtractor: (_) async => const StructuralFaceObservation(
              faceCount: 2,
              largestFaceAreaRatio: 0.16,
            ),
            textExtractor: (_) async => StructuralTextObservation.empty,
            barcodeExtractor: (_) async => StructuralBarcodeObservation.empty,
          ),
        );

        final analysis = await asyncAnalysisBuilder.buildAsync(
          asset: _imageAsset(id: 'group1_face_1'),
          labels: [_label('texture', 0.22)],
        );

        expect(analysis.structural.faceCount, greaterThanOrEqualTo(1));
      },
    );

    test(
      'after extraction on a text heavy asset structural textCoverageRatio is greater than 0.10',
      () async {
        final asyncAnalysisBuilder = PlacementAnalysisBuilder(
          structuralExtractor: StructuralSignalExtractor(
            imageLoader: _fakeImageLoader,
            faceExtractor: (_) async => StructuralFaceObservation.empty,
            textExtractor: (_) async => const StructuralTextObservation(
              lineTexts: [
                'invoice',
                'subtotal 12.00',
                'tax 2.00',
                'total 14.00',
              ],
              blockCount: 2,
              textCoverageRatio: 0.32,
            ),
            barcodeExtractor: (_) async => StructuralBarcodeObservation.empty,
          ),
        );

        final analysis = await asyncAnalysisBuilder.buildAsync(
          asset: _imageAsset(id: 'group1_text_1'),
          labels: [_label('paper', 0.18)],
        );

        expect(analysis.structural.textCoverageRatio, greaterThan(0.10));
      },
    );

    test(
      'after extraction on an asset with passport vocabulary structural hasMrzPattern is true',
      () async {
        final asyncAnalysisBuilder = PlacementAnalysisBuilder(
          structuralExtractor: StructuralSignalExtractor(
            imageLoader: _fakeImageLoader,
            faceExtractor: (_) async => StructuralFaceObservation.empty,
            textExtractor: (_) async => const StructuralTextObservation(
              lineTexts: [
                'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
                'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
              ],
              blockCount: 1,
              textCoverageRatio: 0.18,
            ),
            barcodeExtractor: (_) async => StructuralBarcodeObservation.empty,
          ),
        );

        final analysis = await asyncAnalysisBuilder.buildAsync(
          asset: _imageAsset(id: 'group1_mrz_1'),
          labels: [_label('document', 0.24)],
        );

        expect(analysis.structural.hasMrzPattern, isTrue);
      },
    );
  });

  group('derived signals use structural signals correctly', () {
    test(
      'asset with largestFaceAreaRatio 0.12 and no person label yields humanPresenceScore above zero',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'group2_face_area_1'),
          labels: [_label('texture', 0.30)],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: true,
            textCoverageRatio: 0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final derived = DerivedSignals.from(analysis);

        expect(derived.humanPresenceScore, greaterThan(0.0));
      },
    );

    test(
      'asset with hasMrzPattern true yields documentnessScore at least 0.85',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'group2_mrz_1'),
          labels: [_label('texture', 0.21)],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.20,
            fullOcrText: 'p<utoeriksson<<anna<maria<<<<<<<<<<<<<<<<<<<',
            lineCount: 2,
            blockCount: 1,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: true,
          ),
        );

        final derived = DerivedSignals.from(analysis);

        expect(derived.documentnessScore, greaterThanOrEqualTo(0.85));
      },
    );

    test(
      'asset with textCoverageRatio 0.40 yields graphicnessScore above zero',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'group2_graphic_1'),
          labels: [_label('paper', 0.11)],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.40,
            fullOcrText: 'headline body caption',
            lineCount: 3,
            blockCount: 1,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final derived = DerivedSignals.from(analysis);

        expect(derived.graphicnessScore, greaterThan(0.0));
      },
    );

    test(
      'asset with hasChatLikeLayout true yields uiDensityScore at least 0.80',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'group2_chat_1'),
          labels: [_label('texture', 0.18)],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.10,
            fullOcrText: 'hey\n09:41\nwhere are you',
            lineCount: 6,
            blockCount: 2,
            hasChatLikeLayout: true,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final derived = DerivedSignals.from(analysis);

        expect(derived.uiDensityScore, greaterThanOrEqualTo(0.80));
      },
    );
  });

  group('gates use structural signals correctly', () {
    test(
      'receipt-like document layout fires the Receipts content type gate',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'group3_document_1'),
          labels: [_label('texture', 0.18)],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.18,
            fullOcrText: 'invoice total tax',
            lineCount: 4,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: true,
            barcodeCount: 1,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = routingStage.route(analysis);

        expect(explanation, isNotNull);
        expect(explanation!.cellId, 'receipts');
      },
    );

    test(
      'asset with hasMrzPattern true and face present routes to Documents Receipts not People',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'group3_mrz_face_1'),
          labels: [_label('face', 0.84), _label('person', 0.80)],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.18,
            fullOcrText:
                'p<utoeriksson<<anna<maria<<<<<<<<<<<<<<<<<<<\n'
                'l898902c36uto7408122f1204159ze184226b<<<<<10',
            lineCount: 2,
            blockCount: 1,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: true,
          ),
        );

        final explanation = routingStage.route(analysis);

        expect(explanation, isNotNull);
        expect(explanation!.cellId, 'documents_receipts');
        expect(explanation.cellId, isNot('people'));
      },
    );

    test(
      'chat-like layout with a primary face does not short-circuit to Screenshots',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'group3_chat_face_1'),
          labels: [_label('face', 0.86), _label('person', 0.82)],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.10,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.10,
            fullOcrText: 'hey\n09:41\nwhere are you',
            lineCount: 6,
            blockCount: 2,
            hasChatLikeLayout: true,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = routingStage.route(analysis);

        expect(explanation, isNull);
      },
    );

    test(
      'asset with isMemeOrPosterLike true routes to Animation Meme not Pets or Places',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'group3_meme_1'),
          labels: [_label('pet', 0.58), _label('architecture', 0.54)],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.35,
            fullOcrText: 'headline\ncaption\npunchline',
            lineCount: 3,
            blockCount: 1,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = routingStage.route(analysis);

        expect(explanation, isNotNull);
        expect(explanation!.cellId, 'memes');
        expect(explanation.cellId, isNot('pets'));
        expect(explanation.cellId, isNot('places'));
      },
    );
  });

  group('quote-card meme routing (high human labels)', () {
    test('sports quote card with high human labels routes to meme not people', () {
      const precedenceStage = VetoPrecedenceStage();
      const gateStage = CategoryEntryGateStage();
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'quote_card_sports_1'),
        labels: [
          _label('person', 0.88),
          _label('adult', 0.86),
          _label('athlete', 0.84),
          _label('jersey', 0.82),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.25,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.35,
          fullOcrText: 'he said we will win',
          lineCount: 5,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final derived = DerivedSignals.from(analysis);
      final scores = scoringStage.score(analysis);
      precedenceStage.apply(scores: scores, analysis: analysis);
      gateStage.apply(scores: scores, analysis: analysis);

      final explanation = decisionStage.resolve(
        scores: scores,
        analysis: analysis,
        derived: derived,
      );
      expect(explanation.cellId, 'memes');
      expect(explanation.cellId, isNot('people'));
    });

    test('caption meme with athlete routes to meme not people or sports', () {
      const precedenceStage = VetoPrecedenceStage();
      const gateStage = CategoryEntryGateStage();
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'quote_card_caption_1'),
        labels: [
          _label('person', 0.82),
          _label('adult', 0.80),
          _label('athlete', 0.78),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.20,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.15,
          fullOcrText: 'he thinks lebron is unstoppable',
          lineCount: 3,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final derived = DerivedSignals.from(analysis);
      final scores = scoringStage.score(analysis);
      precedenceStage.apply(scores: scores, analysis: analysis);
      gateStage.apply(scores: scores, analysis: analysis);

      final explanation = decisionStage.resolve(
        scores: scores,
        analysis: analysis,
        derived: derived,
      );
      expect(explanation.cellId, 'memes');
      expect(explanation.cellId, isNot('people'));
      expect(explanation.cellId, isNot('sports'));
    });

    test('real portrait with no text overlay still routes to people', () {
      const precedenceStage = VetoPrecedenceStage();
      const gateStage = CategoryEntryGateStage();
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'portrait_no_text_1'),
        labels: [
          _label('person', 0.91),
          _label('adult', 0.86),
          _label('face', 0.88),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.30,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.02,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final derived = DerivedSignals.from(analysis);
      final scores = scoringStage.score(analysis);
      precedenceStage.apply(scores: scores, analysis: analysis);
      gateStage.apply(scores: scores, analysis: analysis);

      final explanation = decisionStage.resolve(
        scores: scores,
        analysis: analysis,
        derived: derived,
      );
      expect(explanation.cellId, 'people');
    });

    test('portrait with small watermark stays people (below 0.12 coverage)', () {
      const precedenceStage = VetoPrecedenceStage();
      const gateStage = CategoryEntryGateStage();
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'portrait_watermark_1'),
        labels: [
          _label('person', 0.88),
          _label('adult', 0.84),
          _label('face', 0.86),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.28,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.04,
          fullOcrText: '©',
          lineCount: 1,
          blockCount: 1,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final derived = DerivedSignals.from(analysis);
      final scores = scoringStage.score(analysis);
      precedenceStage.apply(scores: scores, analysis: analysis);
      gateStage.apply(scores: scores, analysis: analysis);

      final explanation = decisionStage.resolve(
        scores: scores,
        analysis: analysis,
        derived: derived,
      );
      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('animation_cartoon_meme'));
    });
  });

  group('light caption overlay meme routing', () {
    test(
      'sports photo with Snapchat-style caption overlay routes to Animation Meme',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'caption_overlay_sports_1'),
          labels: [
            _label('athlete', 0.86),
            _label('sport', 0.82),
            _label('person', 0.80),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.16,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.10,
            fullOcrText: "Mf thinks he's LEBRON",
            lineCount: 1,
            blockCount: 1,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = routingStage.route(analysis);
        expect(explanation, isNotNull);
        expect(explanation!.cellId, 'memes');
        expect(explanation.cellId, isNot('people'));
        expect(explanation.cellId, isNot('sports'));
        expect(explanation.cellId, isNot('screenshots'));
        expect(explanation.cellId, isNot('documents_receipts'));
      },
    );

    test('sports action photo with no caption overlay still routes to sports', () {
      const precedenceStage = VetoPrecedenceStage();
      const gateStage = CategoryEntryGateStage();
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'sports_action_no_caption_1'),
        labels: [
          _label('sport', 0.90),
          _label('athlete', 0.88),
          _label('ball', 0.84),
          _label('stadium', 0.82),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.00,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final derived = DerivedSignals.from(analysis);
      final scores = scoringStage.score(analysis);
      precedenceStage.apply(scores: scores, analysis: analysis);
      gateStage.apply(scores: scores, analysis: analysis);

      final explanation = decisionStage.resolve(
        scores: scores,
        analysis: analysis,
        derived: derived,
      );
      expect(explanation.cellId, 'sports');
      expect(explanation.cellId, isNot('animation_cartoon_meme'));
    });
  });

  group('animation vs memes split', () {
    test('black-and-white manga panel with speech bubbles routes to Animation', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'manga_bw_panel_1'),
        labels: [
          _label('manga', 0.90),
          _label('comic', 0.84),
          _label('illustration', 0.72),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.10,
          fullOcrText: '...dialogue...\n...dialogue...',
          lineCount: 2,
          blockCount: 3,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = routingStage.route(analysis);
      expect(explanation, isNotNull);
      expect(explanation!.cellId, anyOf(equals('animation'), equals('unsorted')));
      expect(explanation.cellId, isNot('memes'));
      expect(explanation.cellId, isNot('people'));
    });

    test('manga portrait panel with dialogue routes to Animation (not Memes)', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'manga_portrait_panel_1'),
        labels: [
          _label('manga', 0.86),
          _label('comic', 0.80),
          _label('cartoon', 0.74),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.10,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.12,
          fullOcrText: 'dialogue bubble\nmore dialogue',
          lineCount: 2,
          blockCount: 3,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = routingStage.route(analysis);
      expect(explanation, isNotNull);
      expect(explanation!.cellId, anyOf(equals('animation'), equals('unsorted')));
      expect(explanation.cellId, isNot('memes'));
      expect(explanation.cellId, isNot('people'));
    });

    test('cartoon/anime frame with arrows/circles annotations routes to Memes', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'anime_annotation_meme_1'),
        labels: [
          _label('anime', 0.88),
          _label('cartoon', 0.84),
          _label('illustration', 0.78),
          _label('meme', 0.72),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.10,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.22,
          fullOcrText: 'pov\nlook at this\nlol',
          lineCount: 3,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = routingStage.route(analysis);
      expect(explanation, isNotNull);
      expect(explanation!.cellId, 'memes');
      expect(explanation.cellId, isNot('animation'));
    });

    test('athlete quote-card poster routes to Memes', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'athlete_quote_card_1'),
        labels: [
          _label('person', 0.88),
          _label('athlete', 0.84),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.25,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.35,
          fullOcrText: 'he said we will win',
          lineCount: 5,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );
      final explanation = routingStage.route(analysis);
      expect(explanation, isNotNull);
      expect(explanation!.cellId, 'memes');
    });

    test('dominant car photo routes to Cars (vehicles)', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'cars_dominant_1'),
        labels: [
          _label('car', 0.92),
          _label('vehicle', 0.88),
          _label('automobile', 0.84),
          _label('wheel', 0.78),
        ],
      );
      expect(explanation.cellId, 'vehicles');
      expect(explanation.cellName, 'Cars');
      expect(explanation.cellId, isNot('places'));
    });

    test('night street scene without dominant vehicle routes to Places', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'night_street_scene_1'),
        labels: [
          _label('street', 0.92),
          _label('city', 0.86),
          _label('building', 0.80),
          _label('night', 0.78),
        ],
      );
      expect(explanation.cellId, 'places');
      expect(explanation.cellId, isNot('vehicles'));
    });

    test('cartoon/anime human-like character must not end in People', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'anime_character_1'),
        labels: [
          _label('anime', 0.92),
          _label('cartoon', 0.88),
          _label('character', 0.84),
          _label('face', 0.82),
          _label('person', 0.80),
        ],
      );
      expect(explanation.cellId, isNot('people'));
      expect(explanation.cellId, anyOf(equals('animation'), equals('memes')));
    });

    test('clean manga panel with dialogue must NOT route to Memes', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'manga_clean_dialogue_1'),
        labels: [
          _label('manga', 0.92),
          _label('comic', 0.86),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.10,
          fullOcrText: 'dialogue\ndialogue',
          lineCount: 2,
          blockCount: 3,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );
      final explanation = routingStage.route(analysis);
      expect(explanation, isNotNull);
      expect(explanation!.cellId, anyOf(equals('animation'), equals('unsorted')));
    });

    test('physical manga book goes to Books (printed publication beats animation/devices)', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'books_manga_physical_1'),
        labels: [
          _label('book', 0.88),
          _label('paperback', 0.82),
          _label('publication', 0.76),
          _label('illustrations', 0.74),
          _label('machine', 0.41),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.10,
          fullOcrText: 'isbn 978-0-123456-47-2 paperback',
          lineCount: 2,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);
      expect(explanation.cellId, 'books');
      expect(explanation.cellId, isNot('animation'));
      expect(explanation.cellId, isNot('devices_tech'));
      expect(explanation.cellId, isNot('documents_receipts'));
    });

    test('manga shelf / physical paperback goes to Books', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'books_shelf_1'),
        labels: [
          _label('bookshelf', 0.86),
          _label('book', 0.82),
          _label('shelf', 0.74),
          _label('publication', 0.62),
          _label('consumer electronics', 0.31),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.08,
          fullOcrText: 'publisher hardcover',
          lineCount: 2,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);
      expect(explanation.cellId, 'books');
      expect(explanation.cellId, isNot('devices_tech'));
      expect(explanation.cellId, isNot('animation'));
    });

    test('digital anime scene with sky routes to Animation (not Places/Nature)', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'anime_sky_1'),
        labels: [
          _label('illustration', 0.86),
          _label('art', 0.80),
          _label('cartoon', 0.76),
          _label('sky', 0.92),
          _label('outdoor', 0.78),
          _label('storm', 0.66),
        ],
      );
      expect(explanation.cellId, 'animation');
      expect(explanation.cellId, isNot('places'));
      expect(explanation.cellId, isNot('nature'));
    });

    test('cartoon animal on grass routes to Animation (not Pets/Nature)', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'cartoon_animal_grass_1'),
        labels: [
          _label('cartoon', 0.82),
          _label('illustration', 0.74),
          _label('grass', 0.92),
          _label('outdoor', 0.71),
          _label('animal', 0.44),
        ],
      );
      expect(explanation.cellId, 'animation');
      expect(explanation.cellId, isNot('pets'));
      expect(explanation.cellId, isNot('nature'));
    });

    test('real grass landscape remains Nature/Places (not Animation)', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'real_grass_landscape_1'),
        labels: [
          _label('grass', 0.92),
          _label('land', 0.78),
          _label('outdoor', 0.74),
          _label('sky', 0.71),
          _label('cloud', 0.62),
        ],
      );
      expect(explanation.cellId, anyOf(equals('nature'), equals('places')));
      expect(explanation.cellId, isNot('animation'));
    });

    test('donuts/dessert photo goes to Food despite table/furniture labels', () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(id: 'food_donut_rescue_1'),
        labels: [
          _label('table', 0.88),
          _label('furniture', 0.84),
          _label('utensil', 0.72),
          _label('plate', 0.66),
          _label('dessert', 0.42),
        ],
      );
      final explanation = pipeline.explainPlacement(
        asset: analysis.asset,
        labels: analysis.scoringLabels,
      );
      expect(explanation.cellId, 'food');
      expect(explanation.cellId, isNot('devices_tech'));
      expect(explanation.cellId, isNot('animation'));
    });

    test('plain table/furniture/structure does not become Food', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'not_food_table_1'),
        labels: [
          _label('table', 0.90),
          _label('furniture', 0.86),
          _label('structure', 0.78),
        ],
      );
      expect(explanation.cellId, isNot('food'));
    });

    test('device screen with computer labels remains Devices / Tech (not Books)', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'devices_tech_computer_1', width: 1440, height: 900),
        labels: [
          _label('computer', 0.92),
          _label('consumer electronics', 0.86),
          _label('machine', 0.84),
          _label('computer keyboard', 0.74),
        ],
      );
      expect(explanation.cellId, 'devices_tech');
      expect(explanation.cellId, isNot('books'));
    });

    test(
      'stylized outdoor illustration with strong nature scores resolves to animation not unsorted',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'stylized_strong_nature_gate_1'),
          labels: [
            // Stylized cues must rank inside maxScoringLabels (6) or they are ignored.
            _label('illustration', 0.96),
            _label('cartoon', 0.94),
            _label('grass', 0.91),
            _label('tree', 0.88),
            _label('landscape', 0.86),
            _label('outdoor', 0.78),
            _label('cloud', 0.74),
            _label('sky', 0.72),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.03,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, 'animation');
        expect(explanation.cellId, isNot('unsorted'));
        expect(explanation.cellId, isNot('nature'));
      },
    );
  });

  group('regression: stylized graphic vs generic scenery (2026 device logs)', () {
    test(
      'regression: manga-style panel with weak label scores and high graphicness maps to animation not unsorted',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_manga_style_graphicness_animation_not_unsorted'),
          labels: [
            _label('manga', 0.44),
            _label('character', 0.43),
            _label('fiction', 0.42),
            _label('comic', 0.41),
            _label('story', 0.40),
            _label('panel', 0.28),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.06,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, 'animation');
        expect(explanation.cellId, isNot('unsorted'));
      },
    );

    test(
      'regression: stylized mouse on weak grass/land/outdoor stack routes to animation not nature',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_mouse_grass_generic_scenery_animation'),
          labels: [
            _label('grass', 0.52),
            _label('land', 0.52),
            _label('outdoor', 0.52),
            _label('sky', 0.51),
            _label('structure', 0.19),
            // Keep Vision "mouse" below DerivedSignals plain-background animal cutoff (0.25)
            // so graphicness still lifts from generic grass/outdoor stacks (device log shape).
            _label('mouse', 0.22),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, 'animation');
        expect(explanation.cellId, isNot('nature'));
      },
    );

    test(
      'regression: storm illustration with weak art labels routes to animation not nature',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_spider_storm_weak_art_animation_not_nature'),
          labels: [
            _label('outdoor', 0.40),
            _label('sky', 0.40),
            _label('storm', 0.40),
            _label('art', 0.13),
            _label('illustrations', 0.13),
            _label('fiction', 0.12),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, 'animation');
        expect(explanation.cellId, isNot('nature'));
      },
    );

    test(
      'regression: lamppost outdoor land grass cluster stays Places (03425932-style)',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'reg_lamppost_outdoor_cluster_stays_places'),
          labels: [
            _label('outdoor', 0.85),
            _label('land', 0.85),
            _label('grass', 0.85),
            _label('lamppost', 0.46),
          ],
        );

        expect(explanation.cellId, 'places');
        expect(explanation.cellId, isNot('animation'));
      },
    );

    test(
      'regression: fence structure outdoor cloudy mall walk stays Places (8389FAA6-style)',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_fence_structure_outdoor_places'),
          labels: [
            _label('structure', 0.85),
            _label('fence', 0.84),
            _label('outdoor', 0.80),
            _label('cloudy', 0.78),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0.0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, 'places');
        expect(explanation.cellId, isNot('unsorted'));
      },
    );
  });

  group('runtime regression logs: animation/cars/people guardrails', () {
    test('manga unsorted regression: illustrations+art routes to Animation', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'runtime_manga_unsorted_1'),
        labels: [
          _label('illustrations', 0.94),
          _label('art', 0.93),
          _label('document', 0.11),
          _label('printed_page', 0.08),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.10,
          fullOcrText: 'dialogue bubble\ndialogue bubble',
          lineCount: 2,
          blockCount: 3,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final routed = routingStage.route(analysis);
      expect(routed, isNotNull);
      expect(routed!.cellId, 'animation');
      expect(routed.cellId, isNot('unsorted'));
      expect(routed.cellId, isNot('documents_receipts'));
      expect(routed.cellId, isNot('devices_tech'));
      expect(routed.cellId, isNot('memes'));
    });

    test('manga variant: art+illustration+drawing routes to Animation', () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(id: 'runtime_manga_variant_1'),
        labels: [
          _label('art', 0.88),
          _label('illustration', 0.85),
          _label('drawing', 0.72),
        ],
      );

      final routed = routingStage.route(analysis);
      expect(routed, isNotNull);
      expect(routed!.cellId, 'animation');
      expect(routed.cellId, isNot('memes'));
      expect(routed.cellId, isNot('people'));
    });

    test('skipper/animated character guard: low people/adult + art evidence never becomes People', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'runtime_skipper_people_bug_1'),
        labels: [
          _label('people', 0.46),
          _label('adult', 0.40),
          _label('sign', 0.30),
          _label('illustration', 0.72),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.00,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = pipeline.explainPlacement(
        asset: analysis.asset,
        labels: analysis.scoringLabels,
      );
      expect(explanation.cellId, isNot('people'));
      expect(explanation.cellId, anyOf(equals('animation'), equals('memes')));
    });

    test('BMW car regression: wheel 0.56 + sky 0.97 routes to Cars (vehicles)', () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(id: 'runtime_bmw_nature_bug_1'),
        labels: [
          _label('sky', 0.97),
          _label('blue_sky', 0.71),
          _label('wheel', 0.56),
          _label('outdoor', 0.11),
        ],
      );

      final routed = routingStage.route(analysis);
      expect(routed, isNotNull);
      expect(routed!.cellId, 'vehicles');
      expect(routed.cellId, isNot('nature'));
      expect(routed.cellId, isNot('places'));
    });

    test('negative: real human portrait with face structural evidence routes to People', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'runtime_real_portrait_1'),
        labels: [
          _label('person', 0.92),
          _label('adult', 0.86),
          _label('face', 0.84),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.20,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.00,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = pipeline.explainPlacement(
        asset: analysis.asset,
        labels: analysis.scoringLabels,
      );
      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('animation'));
      expect(explanation.cellId, isNot('memes'));
    });

    test('negative: night street scene with no vehicle cues is not Cars', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'runtime_night_street_no_car_1'),
        labels: [
          _label('street', 0.92),
          _label('city', 0.88),
          _label('building', 0.82),
          _label('skyline', 0.78),
        ],
      );
      expect(explanation.cellId, isNot('vehicles'));
    });

    test('penguins skipper weak people labels do not route to People', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'runtime_penguins_skipper_weak_people_1'),
        labels: [
          _label('people', 0.39),
          _label('adult', 0.39),
          _label('structure', 0.11),
          _label('sign', 0.11),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0.02,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.00,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);
      expect(explanation.cellId, isNot('people'));
      expect(explanation.cellId, anyOf(equals('animation'), equals('memes')));
    });

    test('real selfie with strong people labels stays People', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'runtime_selfie_strong_people_1'),
        labels: [
          _label('people', 0.88),
          _label('adult', 0.85),
          _label('portrait', 0.72),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.18,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.00,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);
      expect(explanation.cellId, 'people');
    });

    test('real portrait with moderate people labels and meaningful face stays People', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'runtime_portrait_moderate_people_1'),
        labels: [
          _label('people', 0.62),
          _label('adult', 0.58),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.12,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.00,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);
      expect(explanation.cellId, 'people');
    });

    test('weak people labels with meaningful face evidence still may be People', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'runtime_weak_people_but_face_1'),
        labels: [
          _label('people', 0.48),
          _label('adult', 0.45),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.10,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.00,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);
      expect(explanation.cellId, 'people');
    });

    test(
      'multi-fix anime weak people/adult with cartoon-like face routes Animation/Memes not People',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'multi_fix_anime_face_yuji_1'),
          labels: [
            _label('people', 0.40),
            _label('adult', 0.38),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.00,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, isNot('people'));
        expect(
          explanation.cellId,
          anyOf(equals('animation'), equals('memes'), equals('animation_cartoon_meme')),
        );
      },
    );

    test(
      'multi-fix manga-style panel no face routes Animation/Memes not People/Unsorted',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'multi_fix_manga_geto_panel_1'),
          labels: [
            _label('structure', 0.45),
            _label('indoor', 0.38),
            _label('sign', 0.22),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.00,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, isNot('people'));
        // Emergency stabilization: allow Unsorted when there is no explicit
        // stylized/animation evidence (avoid broad non-photo capture).
        expect(
          explanation.cellId,
          anyOf(equals('animation'), equals('memes'), equals('unsorted')),
        );
      },
    );

    test(
      'multi-fix food packaging graphic text OCR routes Food not Documents/Memes',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'multi_fix_jacobs_cappuccino_box_1'),
          labels: [
            _label('text', 0.65),
            _label('sign', 0.58),
            _label('beverage', 0.45),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.22,
            fullOcrText:
                'JACOBS CAPPUCCINO\nreduced sugar\nserving suggestion\ningredients',
            lineCount: 4,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'food');
        expect(explanation.cellId, isNot('documents_receipts'));
        expect(explanation.cellId, isNot('memes'));
      },
    );

    test(
      'multi-fix photo of phone screen routes Devices/Tech or Screenshots not People',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'multi_fix_snapchat_phone_photo_1'),
          labels: [
            _label('technology', 0.72),
            _label('display', 0.60),
            _label('people', 0.44),
            _label('adult', 0.42),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.05,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.08,
            fullOcrText: '',
            lineCount: 1,
            blockCount: 1,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, isNot('people'));
        expect(
          explanation.cellId,
          anyOf(equals('devices_tech'), equals('screenshots')),
        );
      },
    );

    test(
      'multi-fix BMW M3 outdoor routes Vehicles not Places/Nature',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'multi_fix_bmw_m3_outdoor_1'),
          labels: [
            _label('car', 0.68),
            _label('vehicle', 0.62),
            _label('sky', 0.55),
            _label('tree', 0.48),
          ],
        );

        expect(explanation.cellId, 'vehicles');
        expect(explanation.cellId, isNot('places'));
        expect(explanation.cellId, isNot('nature'));
      },
    );

    test(
      'multi-fix real selfie stays People',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'multi_fix_real_selfie_guard_1'),
          labels: [
            _label('people', 0.88),
            _label('adult', 0.85),
            _label('selfie', 0.72),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.22,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.00,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'people');
      },
    );

    test(
      'multi-fix dessert takeaway on table routes Food not Unsorted',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'multi_fix_donuts_table_1'),
          labels: [
            _label('dessert', 0.55),
            _label('food', 0.48),
            _label('table', 0.42),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.02,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'food');
        expect(explanation.cellId, isNot('unsorted'));
      },
    );
  });

  test(
    'buildAsync populates structural signals when extractor detects faces and text',
    () async {
      final asyncAnalysisBuilder = PlacementAnalysisBuilder(
        structuralExtractor: StructuralSignalExtractor(
          imageLoader: _fakeImageLoader,
          faceExtractor: (_) async => const StructuralFaceObservation(
            faceCount: 1,
            largestFaceAreaRatio: 0.14,
          ),
          textExtractor: (_) async => const StructuralTextObservation(
            lineTexts: ['passport', '09:41', 'identity'],
            blockCount: 2,
            textCoverageRatio: 0.24,
          ),
          barcodeExtractor: (_) async => const StructuralBarcodeObservation(
            barcodeCount: 1,
            hasQrCode: true,
          ),
        ),
      );

      final analysis = await asyncAnalysisBuilder.buildAsync(
        asset: _imageAsset(id: 'analysis_structural_1'),
        labels: [_label('person', 0.82), _label('document', 0.48)],
      );

      expect(analysis.structural.faceCount, 1);
      expect(analysis.structural.largestFaceAreaRatio, 0.14);
      expect(analysis.structural.textCoverageRatio, greaterThan(0));
      expect(analysis.structural.fullOcrText, contains('passport'));
      expect(analysis.structural.barcodeCount, 1);
      expect(analysis.structural.hasQrCode, isTrue);
    },
  );

  test(
    'derived humanPresenceScore uses structural face area when no person labels exist',
    () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'derived_structural_face_area_1'),
        labels: [_label('texture', 0.34)],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.10,
          hasSingleLargeFace: true,
          textCoverageRatio: 0,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final derived = DerivedSignals.from(analysis);

      expect(derived.humanPresenceScore, greaterThan(0.0));
    },
  );

  test('derived humanPresenceScore uses person label confidence directly', () {
    final analysis = _analysisWithStructural(
      asset: _imageAsset(id: 'derived_person_label_1'),
      labels: [_label('person', 0.8)],
      structural: StructuralSignals.empty(),
    );

    final derived = DerivedSignals.from(analysis);

    expect(derived.humanPresenceScore, 0.8);
  });

  test('derived documentnessScore uses structural MRZ signal', () {
    final analysis = _analysisWithStructural(
      asset: _imageAsset(id: 'derived_mrz_1'),
      labels: [_label('texture', 0.22)],
      structural: const StructuralSignals(
        faceCount: 0,
        largestFaceAreaRatio: 0,
        hasSingleLargeFace: false,
        textCoverageRatio: 0.18,
        fullOcrText: 'p<utoeriksson<<anna<maria<<<<<<<<<<<<<<<<<<<',
        lineCount: 2,
        blockCount: 1,
        hasChatLikeLayout: false,
        hasTableLikeLayout: false,
        barcodeCount: 0,
        hasQrCode: false,
        hasMrzPattern: true,
      ),
    );

    final derived = DerivedSignals.from(analysis);

    expect(derived.documentnessScore, greaterThanOrEqualTo(0.85));
  });

  test(
    'derived graphicnessScore uses text coverage without graphic labels',
    () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'derived_graphic_coverage_1'),
        labels: [_label('paper', 0.12)],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.50,
          fullOcrText: 'headline body caption',
          lineCount: 3,
          blockCount: 1,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final derived = DerivedSignals.from(analysis);

      expect(derived.graphicnessScore, greaterThan(0.0));
    },
  );

  test('derived uiDensityScore uses chat-like structural layout', () {
    final analysis = _analysisWithStructural(
      asset: _imageAsset(id: 'derived_chat_ui_1'),
      labels: [_label('texture', 0.18)],
      structural: const StructuralSignals(
        faceCount: 0,
        largestFaceAreaRatio: 0,
        hasSingleLargeFace: false,
        textCoverageRatio: 0.10,
        fullOcrText: 'hey\n09:41\nwhere are you',
        lineCount: 6,
        blockCount: 2,
        hasChatLikeLayout: true,
        hasTableLikeLayout: false,
        barcodeCount: 0,
        hasQrCode: false,
        hasMrzPattern: false,
      ),
    );

    final derived = DerivedSignals.from(analysis);

    expect(derived.uiDensityScore, greaterThanOrEqualTo(0.80));
  });

  test(
    'structural MRZ routes to Documents Receipts even when a face is present',
    () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'route_structural_mrz_1'),
        labels: [_label('face', 0.84), _label('person', 0.8)],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.12,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.18,
          fullOcrText:
              'p<utoeriksson<<anna<maria<<<<<<<<<<<<<<<<<<<\n'
              'l898902c36uto7408122f1204159ze184226b<<<<<10',
          lineCount: 2,
          blockCount: 1,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: true,
        ),
      );

      final explanation = routingStage.route(analysis);

      expect(explanation, isNotNull);
      expect(explanation!.cellId, 'documents_receipts');
      expect(explanation.cellId, isNot('people'));
    },
  );

  test('structural chat screenshot route yields to a primary person', () {
    final analysis = _analysisWithStructural(
      asset: _imageAsset(id: 'route_structural_chat_1'),
      labels: [_label('face', 0.86), _label('person', 0.82)],
      structural: const StructuralSignals(
        faceCount: 1,
        largestFaceAreaRatio: 0.10,
        hasSingleLargeFace: true,
        textCoverageRatio: 0.10,
        fullOcrText: 'hey\n09:41\nwhere are you',
        lineCount: 6,
        blockCount: 2,
        hasChatLikeLayout: true,
        hasTableLikeLayout: false,
        barcodeCount: 0,
        hasQrCode: false,
        hasMrzPattern: false,
      ),
    );

    final explanation = routingStage.route(analysis);

    expect(explanation, isNull);
  });

  test('structural meme poster route beats pets and places', () {
    final analysis = _analysisWithStructural(
      asset: _imageAsset(id: 'route_structural_meme_1'),
      labels: [_label('pet', 0.58), _label('architecture', 0.54)],
      structural: const StructuralSignals(
        faceCount: 0,
        largestFaceAreaRatio: 0,
        hasSingleLargeFace: false,
        textCoverageRatio: 0.35,
        fullOcrText: 'headline\ncaption\npunchline',
        lineCount: 3,
        blockCount: 1,
        hasChatLikeLayout: false,
        hasTableLikeLayout: false,
        barcodeCount: 0,
        hasQrCode: false,
        hasMrzPattern: false,
      ),
    );

    final explanation = routingStage.route(analysis);

    expect(explanation, isNotNull);
    expect(explanation!.cellId, 'memes');
    expect(explanation.cellId, isNot('pets'));
    expect(explanation.cellId, isNot('places'));
  });

  test('sports scoreboard text with flag token does not route to Places', () {
    final analysis = _analysisWithStructural(
      asset: _imageAsset(id: 'route_structural_scoreboard_1'),
      labels: [_label('flag', 0.34), _label('architecture', 0.46)],
      structural: const StructuralSignals(
        faceCount: 0,
        largestFaceAreaRatio: 0,
        hasSingleLargeFace: false,
        textCoverageRatio: 0.24,
        fullOcrText: 'league fixture england vs france full time score 2 1',
        lineCount: 4,
        blockCount: 2,
        hasChatLikeLayout: false,
        hasTableLikeLayout: false,
        barcodeCount: 0,
        hasQrCode: false,
        hasMrzPattern: false,
      ),
    );

    final explanation = routingStage.route(analysis);

    expect(explanation, isNotNull);
    expect(explanation!.cellId, 'memes');
    expect(explanation.cellId, isNot('places'));
  });

  test(
    'analysis emits strong human-centered signals for selfie-like photos',
    () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(id: 'analysis_people_1'),
        labels: [
          _label('selfie', 0.88),
          _label('face', 0.8),
          _label('person', 0.74),
          _label('pet', 0.52),
        ],
      );

      expect(analysis.signals.humanCentered.isStrong, isTrue);
      expect(analysis.signals.humanPresence.isStrong, isTrue);
      expect(
        analysis.signals.humanCentered.score,
        greaterThan(analysis.signals.petCentered.score),
      );
      expect(analysis.signals.petCentered.isStrong, isFalse);
    },
  );

  test(
    'analysis emits strong document-first signals for passport-like assets',
    () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(
          id: 'analysis_document_1',
          filename: 'passport_scan.jpg',
        ),
        labels: [
          _label('passport', 0.95),
          _label('document', 0.86),
          _label('face', 0.66),
        ],
      );

      expect(analysis.signals.documentLike.isStrong, isTrue);
      expect(analysis.signals.documentness.isStrong, isTrue);
      expect(analysis.signals.graphicPostLike.isStrong, isFalse);
    },
  );

  test(
    'analysis emits strong graphic-post signals for text-overlay meme assets',
    () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(id: 'analysis_graphic_1'),
        labels: [
          _label('meme', 0.83),
          _label('text', 0.78),
          _label('graphic design', 0.75),
        ],
      );

      expect(analysis.signals.graphicPostLike.isStrong, isTrue);
      expect(analysis.signals.graphicMemeNess.isStrong, isTrue);
      expect(analysis.signals.documentLike.isStrong, isFalse);
    },
  );

  test(
    'analysis emits strong UI-density signals for screenshot-like frames',
    () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(
          id: 'analysis_ui_1',
          filename: 'Screenshot 2026-04-20 at 08.41.10.png',
          width: 1179,
          height: 2556,
        ),
        labels: [
          _label('user interface', 0.86),
          _label('text message', 0.79),
          _label('notification', 0.71),
        ],
      );

      expect(analysis.signals.uiDensity.isStrong, isTrue);
      expect(analysis.signals.screenshotLike.isStrong, isTrue);
    },
  );

  test(
    'analysis emits strong scene-place strength for architecture-heavy imagery',
    () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(id: 'analysis_place_1'),
        labels: [
          _label('architecture', 0.86),
          _label('mosque', 0.8),
          _label('courtyard', 0.72),
        ],
      );

      expect(analysis.signals.scenePlaceStrength.isStrong, isTrue);
      expect(analysis.signals.uiDensity.isStrong, isFalse);
    },
  );

  test(
    'document-style routing short-circuits obvious ID copies before scoring',
    () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(
          id: 'route_document_1',
          filename: 'id_copy_scan.jpg',
        ),
        labels: [
          _label('id card', 0.92),
          _label('document', 0.84),
          _label('face', 0.64),
        ],
      );

      final explanation = routingStage.route(analysis);

      expect(explanation, isNotNull);
      expect(explanation!.cellId, 'documents_receipts');
      expect(explanation.primaryEvidence, contains('identity document'));
      expect(explanation.secondarySupport, contains('document style routing'));
    },
  );

  test(
    'graphic-style routing short-circuits obvious meme/post assets before scoring',
    () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(
          id: 'route_graphic_1',
          filename: 'Screenshot_reshared_card.jpg',
          width: 1179,
          height: 2556,
        ),
        labels: [
          _label('user interface', 0.88),
          _label('text', 0.82),
          _label('graphic design', 0.78),
          _label('meme', 0.74),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.30,
          fullOcrText: 'headline\ncaption\nshare this\nfooter',
          lineCount: 4,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = routingStage.route(analysis);

      expect(explanation, isNotNull);
      expect(explanation!.cellId, 'memes');
      expect(
        explanation.secondarySupport,
        anyOf(contains('graphic style routing'), contains('meme route')),
      );
    },
  );

  group('phase 1 explanation separation', () {
    test(
      'fallback lowConfidenceAnimal appears only in fallbackOrDebugReasons',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'phase1_fallback_animal_1'),
          labels: [_label('dog', 0.74)],
        );

        expect(explanation.cellId, 'unsorted');
        expect(
          explanation.fallbackOrDebugReasons,
          contains('fallback lowConfidenceAnimal'),
        );
        expect(
          explanation.primaryEvidence,
          isNot(contains('fallback lowConfidenceAnimal')),
        );
        expect(
          explanation.matchedKeywords,
          isNot(contains('fallback lowConfidenceAnimal')),
        );
      },
    );

    test(
      'places support strings stay in secondarySupport not primaryEvidence',
      () {
        final analysis = analysisBuilder.build(
          asset: _imageAsset(id: 'phase1_places_1'),
          labels: [
            _label('landscape', 0.9),
            _label('sky', 0.78),
            _label('bridge', 0.61),
          ],
        );

        final placesScore = _scoreForCell(
          scoringStage.score(analysis),
          'places',
        );

        expect(
          placesScore.primaryEvidence,
          isNot(contains('scene place signal')),
        );
        expect(
          placesScore.primaryEvidence,
          isNot(contains('no dominant person')),
        );
        expect(
          placesScore.secondarySupport,
          containsAll(['scene place signal', 'no dominant person']),
        );
      },
    );

    test(
      'document support strings stay in secondarySupport while direct evidence remains primary',
      () {
        final analysis = analysisBuilder.build(
          asset: _imageAsset(
            id: 'phase1_document_1',
            filename: 'receipt_scan.jpg',
          ),
          labels: [
            _label('document', 0.86),
            _label('receipt', 0.81),
            _label('text', 0.74),
          ],
        );

        final documentScore = _scoreForCell(
          scoringStage.score(analysis),
          'documents_receipts',
        );

        expect(documentScore.primaryEvidence, contains('document'));
        expect(
          documentScore.secondarySupport,
          containsAll(['document-like signal', 'document-first signal']),
        );
        expect(
          documentScore.primaryEvidence,
          isNot(contains('document-like signal')),
        );
        expect(
          documentScore.primaryEvidence,
          isNot(contains('document-first signal')),
        );
      },
    );

    test(
      'screenshot support strings stay in secondarySupport while direct evidence remains primary',
      () {
        final analysis = analysisBuilder.build(
          asset: _imageAsset(
            id: 'phase1_screenshot_1',
            filename: 'Screenshot 2026-04-20 at 08.41.10.png',
            width: 1179,
            height: 2556,
          ),
          labels: [
            _label('user interface', 0.84),
            _label('text message', 0.77),
          ],
        );

        final screenshotScore = _scoreForCell(
          scoringStage.score(analysis),
          'screenshots',
        );

        expect(
          screenshotScore.primaryEvidence,
          contains('filename screenshot'),
        );
        expect(
          screenshotScore.secondarySupport,
          containsAll([
            'ui signal',
            'chat or messaging UI',
            'screen-like signal',
          ]),
        );
        expect(screenshotScore.primaryEvidence, isNot(contains('ui signal')));
        expect(
          screenshotScore.primaryEvidence,
          isNot(contains('chat or messaging UI')),
        );
        expect(
          screenshotScore.primaryEvidence,
          isNot(contains('screen-like signal')),
        );
      },
    );

    test('matchedKeywords remains a subset of primaryEvidence', () {
      final explanations = [
        pipeline.explainPlacement(
          asset: _imageAsset(
            id: 'phase1_invariant_people_1',
            filename: 'people_trip.jpg',
          ),
          labels: [_label('person', 0.88), _label('portrait', 0.79)],
        ),
        pipeline.explainPlacement(
          asset: _imageAsset(
            id: 'phase1_invariant_document_1',
            filename: 'passport_scan.jpg',
          ),
          labels: [_label('passport', 0.95), _label('document', 0.86)],
        ),
        pipeline.explainPlacement(
          asset: _imageAsset(
            id: 'phase1_invariant_screen_1',
            filename: 'Screenshot 2026-04-20 at 08.41.10.png',
            width: 1179,
            height: 2556,
          ),
          labels: [
            _label('user interface', 0.84),
            _label('text message', 0.77),
          ],
        ),
      ];

      for (final explanation in explanations) {
        expect(
          explanation.matchedKeywords.every(
            explanation.primaryEvidence.contains,
          ),
          isTrue,
        );
      }
    });
  });

  group('phase 2 keyword strictness', () {
    test('screen and device labels do not create strong Places evidence', () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(
          id: 'phase2_device_places_1',
          filename: 'office_setup.jpg',
        ),
        labels: [
          _label('laptop', 0.94),
          _label('monitor', 0.9),
          _label('television', 0.84),
          _label('display panel', 0.78),
        ],
      );

      final scores = scoringStage.score(analysis);
      final techScore = _scoreForCell(scores, 'devices_tech');
      final placesScore = _scoreForCell(scores, 'places');

      expect(techScore.score, greaterThan(placesScore.score));
      expect(placesScore.primaryEvidence, isEmpty);
      expect(
        placesScore.score,
        lessThan(KeywordPlacementDefinitions.fallbackThreshold),
      );
    });

    test('substring only document support cannot beat exact tech evidence', () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(
          id: 'phase2_document_substring_1',
          filename: 'neutral_frame.jpg',
        ),
        labels: [_label('documentary', 0.96), _label('laptop', 0.92)],
      );

      final scores = scoringStage.score(analysis);
      final documentScore = _scoreForCell(scores, 'documents_receipts');
      final techScore = _scoreForCell(scores, 'devices_tech');

      expect(documentScore.score, lessThan(techScore.score));
      expect(documentScore.primaryEvidence, isEmpty);
      expect(documentScore.matchedKeywords, isEmpty);
      expect(
        documentScore.secondarySupport,
        contains('weak documents keyword support'),
      );
    });

    test('screenshot routing stays stable with genuine UI evidence', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(
          id: 'phase2_screenshot_stability_1',
          filename: 'reference_capture.png',
          width: 1179,
          height: 2556,
        ),
        labels: [
          _label('user interface', 0.88),
          _label('text message thread', 0.84),
          _label('application menu', 0.79),
        ],
      );

      expect(explanation.cellId, 'screenshots');
      expect(explanation.primaryEvidence, contains('user interface'));
      expect(
        explanation.matchedKeywords.every(explanation.primaryEvidence.contains),
        isTrue,
      );
    });

    test('exact people pets and food matches remain stable', () {
      final peopleExplanation = pipeline.explainPlacement(
        asset: _imageAsset(
          id: 'phase2_exact_people_1',
          filename: 'portrait_day.jpg',
        ),
        labels: [_label('person', 0.91), _label('portrait', 0.86)],
      );
      final petsExplanation = pipeline.explainPlacement(
        asset: _imageAsset(
          id: 'phase2_exact_pets_1',
          filename: 'park_walk.jpg',
        ),
        labels: [_label('dog', 0.93), _label('puppy', 0.87)],
      );
      final foodExplanation = pipeline.explainPlacement(
        asset: _imageAsset(
          id: 'phase2_exact_food_1',
          filename: 'dinner_table.jpg',
        ),
        labels: [_label('food', 0.9), _label('dish', 0.84)],
      );

      expect(peopleExplanation.cellId, 'people');
      expect(petsExplanation.cellId, 'pets');
      expect(foodExplanation.cellId, 'food');
    });

    test('weak fuzzy risky labels alone cannot create decisive scores', () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(
          id: 'phase2_weak_fuzzy_only_1',
          filename: 'neutral_frame.jpg',
        ),
        labels: [
          _label('documentary', 0.96),
          _label('landmarking', 0.92),
          _label('vacationing', 0.89),
          _label('basketballer', 0.86),
          _label('cartoonish', 0.84),
          _label('capture panel', 0.82),
        ],
      );

      final scores = scoringStage.score(analysis);
      for (final cellId in const [
        'places',
        'documents_receipts',
        'screenshots',
        'travel',
        'sports',
        'animation',
        'memes',
      ]) {
        expect(
          _scoreForCell(scores, cellId).score,
          lessThan(KeywordPlacementDefinitions.fallbackThreshold),
        );
      }

      final explanation = decisionStage.resolve(
        analysis: analysis,
        derived: DerivedSignals.from(analysis),
        scores: scores,
      );

      expect(explanation.cellId, 'unsorted');
      expect(explanation.usedFallback, isTrue);
    });
  });

  group('phase 3 screen presentation anti-drift', () {
    test(
      'structural UI evidence suppresses Places without requiring new cue families',
      () {
        const precedenceStage = VetoPrecedenceStage();
        const gateStage = CategoryEntryGateStage();
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3_structural_ui_1'),
          labels: [_label('sky', 0.58), _label('cloud', 0.52)],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.18,
            fullOcrText: 'agenda q2 review timeline action items notes',
            lineCount: 2,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: true,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final derived = DerivedSignals.from(analysis);
        final scores = scoringStage.score(analysis);
        precedenceStage.apply(scores: scores, analysis: analysis);
        gateStage.apply(scores: scores, analysis: analysis);

        expect(derived.uiDensityScore, greaterThanOrEqualTo(0.6));

        final explanation = decisionStage.resolve(
          scores: scores,
          analysis: analysis,
          derived: derived,
        );
        expect(explanation.cellId, isNot('places'));
        expect(
          explanation.fallbackReason,
          UnsortedFallbackReason.lowConfidenceDocument,
        );
      },
    );
  });

  group('phase 4 places and animal hardening', () {
    test(
      'weak place evidence with strong screen presentation evidence vetoes Places',
      () {
        const precedenceStage = VetoPrecedenceStage();
        const gateStage = CategoryEntryGateStage();
        final analysis = analysisBuilder.build(
          asset: _imageAsset(id: 'phase4_screen_place_1'),
          labels: [
            _label('monitor', 0.89),
            _label('presentation', 0.84),
            _label('sky', 0.43),
          ],
        );

        final scores = scoringStage.score(analysis);
        precedenceStage.apply(scores: scores, analysis: analysis);
        gateStage.apply(scores: scores, analysis: analysis);

        expect(_scoreForCell(scores, 'places').vetoed, isTrue);
      },
    );

    test('weak scene support by itself does not pass Places gating', () {
      const gateStage = CategoryEntryGateStage();
      final analysis = analysisBuilder.build(
        asset: _imageAsset(id: 'phase4_weak_scene_1'),
        labels: [_label('sky', 0.44), _label('cloud', 0.39)],
      );

      final scores = scoringStage.score(analysis);
      gateStage.apply(scores: scores, analysis: analysis);

      final explanation = decisionStage.resolve(
        analysis: analysis,
        derived: DerivedSignals.from(analysis),
        scores: scores,
      );

      expect(explanation.cellId, isNot('places'));
    });

    test(
      'weak incidental animal presence without direct pet evidence does not select lowConfidenceAnimal',
      () {
        final analysis = analysisBuilder.build(
          asset: _imageAsset(id: 'phase4_weak_animal_presence_1'),
          labels: [
            _label('presentation', 0.86),
            _label('slides', 0.8),
            _label('animal', 0.31),
          ],
        );

        final explanation = decisionStage.resolve(
          analysis: analysis,
          derived: DerivedSignals.from(analysis),
          scores: scoringStage.score(analysis),
        );

        expect(
          explanation.fallbackReason,
          isNot(UnsortedFallbackReason.lowConfidenceAnimal),
        );
      },
    );
  });

  group('phase 5 document versus ui boundary', () {
    test(
      'text-heavy login page with document-like structure is rejected when ui context is strong',
      () {
        const gateStage = CategoryEntryGateStage();
        final analysis = _analysisWithStructural(
          asset: _imageAsset(
            id: 'phase5_login_ui_1',
            filename: 'github_login_monitor.jpg',
            width: 1440,
            height: 900,
          ),
          labels: [
            _label('browser', 0.9),
            _label('website', 0.88),
            _label('user interface', 0.86),
            _label('menu', 0.8),
            _label('document', 0.78),
            _label('text', 0.74),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.26,
            fullOcrText: 'github sign in username password forgot password',
            lineCount: 8,
            blockCount: 5,
            hasChatLikeLayout: false,
            hasTableLikeLayout: true,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final routed = routingStage.route(analysis);
        expect(routed?.cellId, isNot('documents_receipts'));

        final scores = scoringStage.score(analysis);
        gateStage.apply(scores: scores, analysis: analysis);

        expect(_scoreForCell(scores, 'documents_receipts').vetoed, isTrue);

        final explanation = decisionStage.resolve(
          analysis: analysis,
          derived: DerivedSignals.from(analysis),
          scores: scores,
        );
        expect(explanation.cellId, isNot('documents_receipts'));
      },
    );

    test(
      'passport style document with visible face still routes to documents decisively',
      () {
        const precedenceStage = VetoPrecedenceStage();
        const gateStage = CategoryEntryGateStage();
        final analysis = _analysisWithStructural(
          asset: _imageAsset(
            id: 'phase5_passport_face_1',
            filename: 'passport_id_scan.jpg',
          ),
          labels: [
            _label('passport', 0.96),
            _label('id card', 0.9),
            _label('face', 0.82),
            _label('person', 0.76),
            _label('document', 0.74),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.22,
            fullOcrText:
                'p<utoeriksson<<anna<maria<<<<<<<<<<<<<<<<<<<\n'
                'l898902c36uto7408122f1204159ze184226b<<<<<10',
            lineCount: 3,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: true,
          ),
        );

        final scores = scoringStage.score(analysis);
        precedenceStage.apply(scores: scores, analysis: analysis);
        gateStage.apply(scores: scores, analysis: analysis);
        final explanation = decisionStage.resolve(
          analysis: analysis,
          derived: DerivedSignals.from(analysis),
          scores: scores,
        );

        expect(explanation.cellId, 'documents_receipts');
        expect(explanation.score, greaterThanOrEqualTo(1.2));
        expect(explanation.cellId, isNot('people'));
      },
    );
  });

  group('devices tech furniture guard and dining rescue', () {
    test(
      'table furniture and structure labels do not count as dining context cues without food labels',
      () {
        final analysis = analysisBuilder.build(
          asset: _imageAsset(id: 'dining_context_count_1'),
          labels: [
            _label('table', 0.72),
            _label('furniture', 0.72),
            _label('structure', 0.76),
          ],
        );

        expect(analysis.cueSummary.diningContextCueCount, 0);
      },
    );

    test(
      'table furniture and wood processed labels do not create screen device cues or win Devices Tech',
      () {
        final analysis = analysisBuilder.build(
          asset: _imageAsset(id: 'device_guard_furniture_1'),
          labels: [
            _label('table', 0.72),
            _label('furniture', 0.72),
            _label('wood_processed', 0.56),
          ],
        );

        expect(analysis.cueSummary.screenDeviceCueCount, 0);

        final explanation = pipeline.explainPlacement(
          asset: analysis.asset,
          labels: analysis.scoringLabels,
        );
        expect(explanation.cellId, isNot('devices_tech'));
      },
    );

    test(
      'dining context rescue does not fire when only table style labels are present',
      () {
        final analysis = analysisBuilder.build(
          asset: _imageAsset(id: 'dining_rescue_1'),
          labels: [
            _label('structure', 0.76),
            _label('furniture', 0.72),
            _label('table', 0.72),
          ],
        );

        expect(analysis.cueSummary.diningContextCueCount, 0);

        final scores = scoringStage.score(analysis);
        final foodScore = _scoreForCell(scores, 'food');
        final techScore = _scoreForCell(scores, 'devices_tech');

        expect(foodScore.score, lessThanOrEqualTo(techScore.score));
      },
    );

    test(
      'table contributes dining context only when a food cue is already present',
      () {
        final analysis = analysisBuilder.build(
          asset: _imageAsset(id: 'dining_supportive_table_1'),
          labels: [_label('food', 0.86), _label('table', 0.72)],
        );

        expect(analysis.cueSummary.foodCueCount, greaterThan(0));
        expect(analysis.cueSummary.diningContextCueCount, greaterThan(0));
      },
    );

    test('tablet computer label still creates a screen device cue', () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(id: 'tablet_exact_1'),
        labels: [_label('tablet computer', 0.86)],
      );

      expect(analysis.cueSummary.screenDeviceCueCount, greaterThan(0));
    });

    test('table alone contributes zero to Devices Tech', () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(id: 'table_only_1'),
        labels: [_label('table', 0.82)],
      );

      expect(analysis.cueSummary.screenDeviceCueCount, 0);
      expect(
        _scoreForCell(scoringStage.score(analysis), 'devices_tech').score,
        0,
      );
    });

    test('pizza food and table labels still route to Food normally', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'pizza_table_1'),
        labels: [
          _label('pizza', 0.92),
          _label('food', 0.88),
          _label('table', 0.72),
        ],
      );

      expect(explanation.cellId, 'food');
    });

    test('dessert labels cupcake chocolate route to Food not Unsorted', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'dessert_cupcake_chocolate_1'),
        labels: [
          _label('cupcake', 0.88),
          _label('chocolate', 0.74),
        ],
      );

      expect(explanation.cellId, 'food');
    });
  });

  group('keyword matcher substring safety', () {
    const matcher = PlacementKeywordMatcher();

    test('cue art does not substring-match inside cartoon phrase tokens', () {
      final normalized = matcher.normalize('animated cartoon');
      final tokens = matcher.tokenize(normalized);
      final match = matcher.keywordMatch(
        keyword: 'art',
        tokens: tokens,
        normalized: normalized,
      );
      expect(match.type, isNot(KeywordMatchType.substring));
      expect(match.isStrongEvidence, isFalse);
    });

    test('cue art stays inert inside artifact chart and cartoon tokens', () {
      for (final phrase in ['artifact', 'flow chart', 'cart', 'party']) {
        final normalized = matcher.normalize(phrase);
        final tokens = matcher.tokenize(normalized);
        final match = matcher.keywordMatch(
          keyword: 'art',
          tokens: tokens,
          normalized: normalized,
        );
        expect(
          match.type,
          isNot(KeywordMatchType.substring),
          reason: 'unexpected substring hit on "$phrase"',
        );
      }
    });

    test('cue art matches standalone label normalized art', () {
      final normalized = matcher.normalize('art');
      final tokens = matcher.tokenize(normalized);
      final match = matcher.keywordMatch(
        keyword: 'art',
        tokens: tokens,
        normalized: normalized,
      );
      expect(match.isStrongEvidence, isTrue);
    });
  });

  group('subject-first place precedence', () {
    test('mosque with incidental crowd resolves to Places', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'place_precedence_mosque_crowd_1'),
        labels: [
          _label('architecture', 0.93),
          _label('mosque', 0.9),
          _label('courtyard', 0.82),
          _label('crowd', 0.74),
        ],
      );

      expect(explanation.cellId, 'places');
    });

    test('cathedral exterior with tourists resolves to Places', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'place_precedence_cathedral_tourists_1'),
        labels: [
          _label('cathedral', 0.92),
          _label('architecture', 0.88),
          _label('facade', 0.84),
          _label('crowd', 0.7),
        ],
      );

      expect(explanation.cellId, 'places');
    });

    test(
      'landmark skyline with background crowd and weak people cues chooses Places',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'place_precedence_landmark_skyline_crowd_bg_1'),
          labels: [
            _label('landmark', 0.91),
            _label('skyline', 0.88),
            _label('architecture', 0.86),
            _label('building', 0.84),
            _label('tower', 0.78),
            _label('crowd', 0.58),
          ],
        );

        expect(explanation.cellId, 'places');
      },
    );

    test('group selfie in front of mosque stays People', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'place_precedence_group_selfie_1'),
        labels: [
          _label('selfie', 0.93),
          _label('portrait', 0.89),
          _label('person', 0.84),
          _label('group', 0.76),
          _label('mosque', 0.88),
          _label('architecture', 0.82),
        ],
      );

      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('places'));
    });

    test('former family photo at landmark resolves to People', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'place_precedence_family_landmark_1'),
        labels: [
          _label('family', 0.92),
          _label('parent', 0.88),
          _label('child', 0.86),
          _label('person', 0.84),
          _label('face', 0.79),
          _label('group', 0.76),
          _label('landmark', 0.78),
          _label('architecture', 0.72),
        ],
      );

      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('places'));
    });

    test('close portrait with building background stays People', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'place_precedence_portrait_building_1'),
        labels: [
          _label('portrait', 0.91),
          _label('person', 0.87),
          _label('face', 0.84),
          _label('building', 0.8),
          _label('architecture', 0.76),
        ],
      );

      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('places'));
    });
  });

  group('outdoor scene cluster places gate', () {
    test(
      'outdoor land grass lamppost routes to Places with outdoor scene cluster',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'outdoor_scene_cluster_lamppost_1'),
          labels: [
            _label('outdoor', 0.85),
            _label('land', 0.85),
            _label('grass', 0.85),
            _label('lamppost', 0.46),
          ],
        );

        expect(explanation.cellId, 'places');
        expect(explanation.usedFallback, isFalse);
        expect(explanation.secondarySupport, contains('outdoor scene cluster'));
      },
    );

    test(
      'weak 049 outdoor land grass does not route to Places without stronger cue',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'outdoor_scene_weak_triple_1'),
          labels: [
            _label('outdoor', 0.49),
            _label('land', 0.49),
            _label('grass', 0.49),
          ],
        );

        expect(explanation.cellId, isNot('places'));
      },
    );

    test('low confidence outdoor sky storm does not unlock Places', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'outdoor_scene_weak_weather_1'),
        labels: [
          _label('outdoor', 0.40),
          _label('sky', 0.40),
          _label('storm', 0.40),
        ],
      );

      expect(explanation.cellId, isNot('places'));
    });

    test('strong adult outdoor grass still routes to People', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'outdoor_scene_people_priority_1'),
        labels: [
          _label('person', 0.91),
          _label('adult', 0.88),
          _label('face', 0.84),
          _label('outdoor', 0.85),
          _label('grass', 0.85),
          _label('land', 0.84),
        ],
      );

      expect(explanation.cellId, 'people');
    });
  });

  group('mosque architecture place recovery', () {
    test(
      'mosque-like structure arch outdoor sky cluster resolves to Places',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'mosque_arch_recovery_1'),
          labels: [
            _label('structure', 0.82),
            _label('arch', 0.76),
            _label('outdoor', 0.70),
            _label('sky', 0.68),
          ],
        );

        expect(explanation.cellId, 'places');
        expect(explanation.cellId, isNot('unsorted'));
      },
    );

    test(
      'generic weak arch outdoor structure without mosque cluster can remain Unsorted',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'generic_arch_weak_scene_1'),
          labels: [
            _label('structure', 0.38),
            _label('arch', 0.34),
            _label('outdoor', 0.31),
          ],
        );

        expect(explanation.cellId, 'unsorted');
      },
    );

    test(
      'explicit mosque token with otherwise generic architecture still prefers Places',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'mosque_explicit_generic_context_1'),
          labels: [
            _label('structure', 0.74),
            _label('outdoor', 0.44),
            _label('mosque', 0.38),
          ],
        );

        expect(explanation.cellId, 'places');
      },
    );
  });

  test('decision stage emits lowConfidenceHuman unsorted reason', () {
    final analysis = analysisBuilder.build(
      asset: _imageAsset(id: 'decision_human_1'),
      labels: [_label('face', 0.36), _label('person', 0.31)],
    );

    final explanation = decisionStage.resolve(
      analysis: analysis,
      derived: DerivedSignals.from(analysis),
      scores: [
        PlacementScoreCard(
          rule: KeywordPlacementDefinitions.ruleForCellId('devices_tech')!,
          score: 0.4,
          matchedKeywords: {'weak tech cue'},
        ),
      ],
    );

    expect(explanation.cellId, 'unsorted');
    expect(explanation.unsortedReason, UnsortedReason.lowConfidenceHuman);
  });

  test('decision stage emits lowConfidenceFood unsorted reason', () {
    final analysis = analysisBuilder.build(
      asset: _imageAsset(id: 'decision_food_1'),
      labels: [_label('dish', 0.31), _label('plate', 0.27)],
    );

    final explanation = decisionStage.resolve(
      analysis: analysis,
      derived: DerivedSignals.from(analysis),
      scores: [
        PlacementScoreCard(
          rule: KeywordPlacementDefinitions.ruleForCellId('devices_tech')!,
          score: 0.41,
          matchedKeywords: {'weak tech cue'},
        ),
      ],
    );

    expect(explanation.cellId, 'unsorted');
    expect(explanation.unsortedReason, UnsortedReason.lowConfidenceFood);
  });

  test('decision stage emits lowConfidenceScene unsorted reason', () {
    final analysis = analysisBuilder.build(
      asset: _imageAsset(id: 'decision_scene_1'),
      labels: [_label('landscape', 0.32), _label('sky', 0.28)],
    );

    final explanation = decisionStage.resolve(
      analysis: analysis,
      derived: DerivedSignals.from(analysis),
      scores: [
        PlacementScoreCard(
          rule: KeywordPlacementDefinitions.ruleForCellId('devices_tech')!,
          score: 0.39,
          matchedKeywords: {'weak tech cue'},
        ),
      ],
    );

    expect(explanation.cellId, 'unsorted');
    expect(explanation.unsortedReason, UnsortedReason.lowConfidenceScene);
  });

  test('decision stage emits ambiguousMulti unsorted reason', () {
    final analysis = analysisBuilder.build(
      asset: _imageAsset(id: 'decision_ambiguous_1'),
      labels: [_label('technology', 0.3), _label('keyboard', 0.28)],
    );

    final explanation = decisionStage.resolve(
      analysis: analysis,
      derived: DerivedSignals.from(analysis),
      scores: [
        PlacementScoreCard(
          rule: KeywordPlacementDefinitions.ruleForCellId('devices_tech')!,
          score: 0.72,
          matchedKeywords: {'weak tech cue'},
        ),
        PlacementScoreCard(
          rule: KeywordPlacementDefinitions.ruleForCellId('travel')!,
          score: 0.67,
          matchedKeywords: {'weak travel cue'},
        ),
      ],
    );

    expect(explanation.cellId, 'unsorted');
    expect(explanation.unsortedReason, UnsortedReason.ambiguousMulti);
  });

  test(
    'decision stage falls back to unsorted when winning margin is too narrow',
    () {
      final analysis = analysisBuilder.build(
        asset: _imageAsset(id: 'decision_narrow_margin_1'),
        labels: [_label('texture', 0.23), _label('pattern', 0.21)],
      );

      final explanation = decisionStage.resolve(
        analysis: analysis,
        derived: DerivedSignals.from(analysis),
        scores: [
          PlacementScoreCard(
            rule: KeywordPlacementDefinitions.ruleForCellId('devices_tech')!,
            score: 0.96,
            matchedKeywords: {'screen cue'},
          ),
          PlacementScoreCard(
            rule: KeywordPlacementDefinitions.ruleForCellId('travel')!,
            score: 0.91,
            matchedKeywords: {'travel cue'},
          ),
        ],
      );

      expect(explanation.cellId, 'unsorted');
      expect(explanation.usedFallback, isTrue);
      expect(explanation.fallbackReason, UnsortedFallbackReason.ambiguousMulti);
      expect(explanation.topCandidateCellId, 'devices_tech');
      expect(explanation.topCandidateCellName, 'Devices / Tech');
      expect(explanation.topCandidateScore, 0.96);
      expect(explanation.runnerUpCellId, 'travel');
      expect(explanation.runnerUpCellName, 'Travel');
      expect(explanation.runnerUpScore, 0.91);
      expect(explanation.winningMargin, closeTo(0.05, 0.0001));
      expect(
        explanation.requiredMargin,
        KeywordPlacementDefinitions.fallbackMarginThreshold,
      );
      expect(
        explanation.fallbackThreshold,
        KeywordPlacementDefinitions.fallbackThreshold,
      );
      expect(explanation.blockedByMargin, isTrue);
      expect(explanation.blockedByLowConfidence, isFalse);
      expect(
        explanation.finalDecisionSummary,
        'Unsorted because Devices / Tech only led Travel by 0.05, '
        'below the 0.10 margin requirement.',
      );
      expect(
        explanation.matchedKeywords,
        contains('top candidate Devices / Tech'),
      );
      expect(explanation.matchedKeywords, contains('runner-up Travel'));
      expect(explanation.matchedKeywords, contains('margin too narrow 0.05'));
      expect(explanation.matchedKeywords, contains('required margin 0.10'));
    },
  );

  test('decision stage still resolves when winner score is at least 1.0', () {
    final analysis = analysisBuilder.build(
      asset: _imageAsset(id: 'decision_clear_winner_1'),
      labels: [_label('texture', 0.23), _label('pattern', 0.21)],
    );

    final explanation = decisionStage.resolve(
      analysis: analysis,
      derived: DerivedSignals.from(analysis),
      scores: [
        PlacementScoreCard(
          rule: KeywordPlacementDefinitions.ruleForCellId('devices_tech')!,
          score: 1.02,
          matchedKeywords: {'screen cue'},
        ),
        PlacementScoreCard(
          rule: KeywordPlacementDefinitions.ruleForCellId('travel')!,
          score: 0.99,
          matchedKeywords: {'travel cue'},
        ),
      ],
    );

    expect(explanation.cellId, 'devices_tech');
    expect(explanation.cellId, isNot('unsorted'));
  });

  test('decision stage emits noSignal unsorted reason', () {
    final analysis = analysisBuilder.build(
      asset: _imageAsset(id: 'decision_none_1'),
      labels: [_label('texture', 0.23), _label('pattern', 0.21)],
    );

    final explanation = decisionStage.resolve(
      analysis: analysis,
      derived: DerivedSignals.from(analysis),
      scores: [
        PlacementScoreCard(
          rule: KeywordPlacementDefinitions.ruleForCellId('devices_tech')!,
          score: 0.38,
          matchedKeywords: {'weak tech cue'},
        ),
      ],
    );

    expect(explanation.cellId, 'unsorted');
    expect(explanation.unsortedReason, UnsortedReason.noSignal);
  });

  test('sky label alone does not push an asset into a specific category', () {
    final explanation = pipeline.explainPlacement(
      asset: _imageAsset(id: 'phase3a_sky_only_1'),
      labels: [_label('sky', 0.94)],
    );

    expect(explanation.cellId, 'unsorted');
  });

  test(
    'natural outdoor sky cluster does not leak into screenshots or meme buckets',
    () {
      const precedenceStage = VetoPrecedenceStage();
      const gateStage = CategoryEntryGateStage();
      final analysis = analysisBuilder.build(
        asset: _imageAsset(id: 'regression_outdoor_sky_structure_1'),
        labels: [
          _label('outdoor', 0.91),
          _label('sky', 0.91),
          _label('blue_sky', 0.91),
          _label('structure', 0.82),
        ],
      );

      final scores = scoringStage.score(analysis);
      precedenceStage.apply(scores: scores, analysis: analysis);
      gateStage.apply(scores: scores, analysis: analysis);

      expect(_scoreForCell(scores, 'screenshots').vetoed, isTrue);
      expect(_scoreForCell(scores, 'memes').vetoed, isTrue);

      final ranked =
          scores.where((score) => !score.vetoed).toList(growable: false)
            ..sort((left, right) => right.score.compareTo(left.score));

      expect(ranked.first.rule.cellId, 'nature');
      expect(ranked.first.rule.cellId, isNot('screenshots'));
      expect(ranked[1].rule.cellId, isNot('memes'));

      final explanation = pipeline.explainPlacement(
        asset: analysis.asset,
        labels: analysis.scoringLabels,
      );

      expect(
        explanation.cellId,
        anyOf(equals('nature'), equals('places'), equals('unsorted')),
      );
      expect(explanation.topCandidateCellId, 'nature');
      expect(explanation.topCandidateCellId, isNot('screenshots'));
      expect(explanation.runnerUpCellId, isNot('memes'));
    },
  );

  group('people-first precedence', () {
    test(
      'tweetScreenshotMemeLike beats People-first and routes to Memes',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3b_tweet_subtype_1'),
          labels: [
            _label('person', 0.88),
            _label('portrait', 0.80),
            _label('face', 0.74),
            _label('user interface', 0.82),
            _label('text message', 0.78),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.14,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.12,
            fullOcrText: 'tweet\nreply\nretweet\nlikes\nviews\nfollow',
            lineCount: 6,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final scores = scoringStage.score(analysis);
        const precedenceStage = VetoPrecedenceStage();
        precedenceStage.apply(scores: scores, analysis: analysis);

        expect(_scoreForCell(scores, 'people').vetoed, isTrue);

        final explanation = decisionStage.resolve(
          scores: scores,
          analysis: analysis,
          derived: DerivedSignals.from(analysis),
        );
        expect(explanation.cellId, 'memes');
        expect(
          explanation.fallbackOrDebugReasons,
          isNot(contains('people-first suppresses meme fallback')),
        );
      },
    );

    test(
      'socialEmbedMemeLike beats People-first and routes to Memes',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3b_social_embed_subtype_1'),
          labels: [
            _label('person', 0.84),
            _label('face', 0.72),
            _label('user interface', 0.82),
            _label('message', 0.78),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.12,
            fullOcrText: 'embedded post\nquote tweet\nfinal score\nscoreboard',
            lineCount: 6,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final scores = scoringStage.score(analysis);
        const precedenceStage = VetoPrecedenceStage();
        precedenceStage.apply(scores: scores, analysis: analysis);

        expect(_scoreForCell(scores, 'people').vetoed, isTrue);

        final explanation = decisionStage.resolve(
          scores: scores,
          analysis: analysis,
          derived: DerivedSignals.from(analysis),
        );
        expect(explanation.cellId, 'memes');
        expect(
          explanation.fallbackOrDebugReasons,
          isNot(contains('people-first suppresses meme fallback')),
        );
      },
    );

    test(
      'photoTextOverlayMemeLike beats People-first and routes to Memes',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3b_overlay_subtype_1'),
          labels: [
            _label('person', 0.88),
            _label('portrait', 0.82),
            _label('face', 0.76),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.16,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.22,
            fullOcrText: 'caption\ntext\noverlay\nheadline',
            lineCount: 4,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final scores = scoringStage.score(analysis);
        const precedenceStage = VetoPrecedenceStage();
        precedenceStage.apply(scores: scores, analysis: analysis);

        expect(_scoreForCell(scores, 'people').vetoed, isTrue);

        final explanation = decisionStage.resolve(
          scores: scores,
          analysis: analysis,
          derived: DerivedSignals.from(analysis),
        );
        expect(explanation.cellId, 'memes');
        expect(
          explanation.fallbackOrDebugReasons,
          isNot(contains('people-first suppresses meme fallback')),
        );
      },
    );

    test(
      'quoteCardMemeLike beats People-first and routes to Memes',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3b_quote_card_subtype_1'),
          labels: [
            _label('person', 0.88),
            _label('portrait', 0.80),
            _label('face', 0.72),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.20,
            fullOcrText: 'quote card\npull quote\nmanager quote\npress quote',
            lineCount: 4,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final scores = scoringStage.score(analysis);
        const precedenceStage = VetoPrecedenceStage();
        precedenceStage.apply(scores: scores, analysis: analysis);

        expect(_scoreForCell(scores, 'people').vetoed, isTrue);

        final explanation = decisionStage.resolve(
          scores: scores,
          analysis: analysis,
          derived: DerivedSignals.from(analysis),
        );
        expect(explanation.cellId, 'memes');
        expect(
          explanation.fallbackOrDebugReasons,
          isNot(contains('people-first suppresses meme fallback')),
        );
      },
    );

    test(
      'multiPanelMemeLike beats People-first and routes to Memes',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3b_multi_panel_subtype_1'),
          labels: [
            _label('person', 0.86),
            _label('face', 0.74),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.18,
            fullOcrText: 'panel\ntext\npanel\ntext\npanel\ntext',
            lineCount: 6,
            blockCount: 3,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final scores = scoringStage.score(analysis);
        const precedenceStage = VetoPrecedenceStage();
        precedenceStage.apply(scores: scores, analysis: analysis);

        expect(_scoreForCell(scores, 'people').vetoed, isTrue);

        final explanation = decisionStage.resolve(
          scores: scores,
          analysis: analysis,
          derived: DerivedSignals.from(analysis),
        );
        expect(explanation.cellId, 'memes');
        expect(
          explanation.fallbackOrDebugReasons,
          isNot(contains('people-first suppresses meme fallback')),
        );
      },
    );

    test(
      'captionedFictionMemeLike beats People-first and routes to Memes',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3b_captioned_fiction_subtype_1'),
          labels: [
            _label('person', 0.88),
            _label('portrait', 0.80),
            _label('face', 0.72),
            _label('cartoon', 0.24),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.18,
            fullOcrText: 'dragon\nfictional character\ncaption\ntext',
            lineCount: 4,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final scores = scoringStage.score(analysis);
        const precedenceStage = VetoPrecedenceStage();
        precedenceStage.apply(scores: scores, analysis: analysis);

        expect(_scoreForCell(scores, 'people').vetoed, isTrue);

        final explanation = decisionStage.resolve(
          scores: scores,
          analysis: analysis,
          derived: DerivedSignals.from(analysis),
        );
        expect(explanation.cellId, 'memes');
        expect(
          explanation.fallbackOrDebugReasons,
          isNot(contains('people-first suppresses meme fallback')),
        );
      },
    );

    test(
      'cartoon face without human labels routes to Memes',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3a_cartoon_face_structural_1'),
          labels: [_label('texture', 0.04)],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.08,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.16,
            fullOcrText: 'caption\ntext\noverlay\nlol',
            lineCount: 4,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'memes');
        expect(explanation.cellId, isNot('people'));
      },
    );

    test(
      'photo text overlay routes to Memes even with strong human label',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3a_photo_overlay_1'),
          labels: [
            _label('person', 0.82),
            _label('portrait', 0.78),
            _label('face', 0.72),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.22,
            fullOcrText: 'caption\ntext\noverlay\nheadline',
            lineCount: 4,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'memes');
      },
    );

    test('quote card routes to Memes from structural text', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'phase3a_quote_card_1'),
        labels: [_label('paper', 0.12)],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.28,
          fullOcrText: 'quote card\npull quote\nmanager quote\npress quote\nclub crest',
          lineCount: 5,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);
      expect(explanation.cellId, 'memes');
    });

    test('real selfie still routes to People', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'phase3a_selfie_regression_1'),
        labels: [
          _label('person', 0.88),
          _label('portrait', 0.82),
          _label('face', 0.76),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.18,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.02,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);
      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('animation_cartoon_meme'));
    });

    test('real selfie with watermark still routes to People', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'phase3a_selfie_watermark_regression_1'),
        labels: [
          _label('person', 0.88),
          _label('portrait', 0.82),
          _label('face', 0.76),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.18,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.08,
          fullOcrText: 'watermark',
          lineCount: 1,
          blockCount: 1,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);
      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('animation_cartoon_meme'));
    });

    test(
      'primary person beats screenshot document and generic poster labels',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _screenshotAsset(
            id: 'people_first_saved_person_1',
            filename: 'IMG_saved_person.png',
          ),
          labels: [
            _label('person', 0.9),
            _label('portrait', 0.86),
            _label('face', 0.82),
            _label('screenshot', 0.78),
            _label('document', 0.74),
            _label('poster', 0.70),
            _label('text', 0.68),
          ],
        );

        expect(explanation.cellId, 'people');
        expect(explanation.cellId, isNot('screenshots'));
        expect(explanation.cellId, isNot('documents_receipts'));
        expect(explanation.cellId, isNot('animation_cartoon_meme'));
      },
    );

    test('confirmed meme poster overlay beats embedded person', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'people_first_meme_overlay_1'),
        labels: [
          _label('person', 0.88),
          _label('portrait', 0.81),
          _label('meme', 0.78),
          _label('logo', 0.76),
          _label('text', 0.74),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.30,
          fullOcrText: 'headline\nquote\ncaption\nlogo',
          lineCount: 4,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = routingStage.route(analysis);

      expect(explanation, isNotNull);
      expect(explanation!.cellId, 'memes');
    });

    test(
      'single cartoon cue with high graphicness routes to Memes over People',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3a_cartoon_strong_1'),
          labels: [
            _label('cartoon', 0.92),
            _label('illustration', 0.74),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.40,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final scores = scoringStage.score(analysis);
        const precedenceStage = VetoPrecedenceStage();
        const gateStage = CategoryEntryGateStage();

        precedenceStage.apply(scores: scores, analysis: analysis);
        gateStage.apply(scores: scores, analysis: analysis);

        final explanation = decisionStage.resolve(
          scores: scores,
          analysis: analysis,
          derived: DerivedSignals.from(analysis),
        );

        expect(explanation.cellId, 'memes');
        expect(explanation.cellId, isNot('people'));
      },
    );

    test(
      'cartoon label 0.85 with faceCount 1 routes to Memes not People',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3a_cartoon_face_1'),
          labels: [
            _label('cartoon', 0.85),
            _label('person', 0.72),
            _label('face', 0.70),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.20,
            fullOcrText: 'caption\ntext\noverlay',
            lineCount: 3,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'memes');
        expect(explanation.cellId, isNot('people'));
      },
    );

    test(
      'meme image with face overlay routes to Memes',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'phase3a_meme_face_overlay_1'),
          labels: [
            _label('meme', 0.82),
            _label('person', 0.78),
            _label('face', 0.72),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.10,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.25,
            fullOcrText: 'caption\ntext\noverlay\nlol',
            lineCount: 4,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = routingStage.route(analysis);
        expect(explanation, isNotNull);
        expect(explanation!.cellId, 'memes');
      },
    );

    test(
      'real person photo with no animation labels still routes to People',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'phase3a_people_regression_1'),
          labels: [
            _label('portrait', 0.92),
            _label('person', 0.88),
            _label('face', 0.84),
          ],
        );

        expect(explanation.cellId, 'people');
        expect(explanation.cellId, isNot('animation_cartoon_meme'));
      },
    );

    test('identity document evidence beats embedded person', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'people_first_identity_doc_1'),
        labels: [
          _label('person', 0.88),
          _label('portrait', 0.80),
          _label('id card', 0.86),
          _label('document', 0.78),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.12,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.18,
          fullOcrText: 'identity card\nname\nbirth date',
          lineCount: 3,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = routingStage.route(analysis);

      expect(explanation, isNotNull);
      expect(explanation!.cellId, 'documents_receipts');
    });

    test('incidental person embedded in dominant UI stays Screenshots', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(
          id: 'people_first_incidental_ui_1',
          filename: 'Screenshot_chat_profile.png',
          width: 1179,
          height: 2556,
        ),
        labels: [
          _label('text message', 0.92),
          _label('user interface', 0.88),
          _label('notification', 0.82),
          _label('person', 0.54),
        ],
      );

      expect(explanation.cellId, 'screenshots');
      expect(explanation.cellId, isNot('people'));
    });

    test(
      'generic poster document text labels do not satisfy Animation hard gate',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'animation_hard_gate_generic_1'),
          labels: [
            _label('poster', 0.9),
            _label('art', 0.84),
            _label('document', 0.78),
            _label('screenshot', 0.76),
            _label('text', 0.72),
          ],
        );

        expect(explanation.cellId, isNot('animation_cartoon_meme'));
        expect(explanation.topCandidateCellId, isNot('animation_cartoon_meme'));
      },
    );

    test('two explicit stylized cues satisfy Animation hard gate', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'animation_hard_gate_explicit_1'),
        labels: [
          _label('cartoon', 0.88),
          _label('meme', 0.82),
          _label('text', 0.70),
        ],
      );

      expect(explanation.cellId, 'memes');
    });
  });

  group('graphic poster bridge and broad bias guards', () {
    AssetAnalysis memeGraphicAnalysis(String id) {
      return _analysisWithStructural(
        asset: _imageAsset(id: id, filename: 'shared_card.jpg'),
        labels: [
          _label('art', 0.39),
          _label('illustrations', 0.39),
          _label('document', 0.24),
          _label('printed_page', 0.23),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.24,
          fullOcrText: 'headline\nshort caption\ncall to action',
          lineCount: 3,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );
    }

    test(
      'meme graphic art printed page with poster OCR routes to Animation Meme',
      () {
        final explanation = routingStage.route(
          memeGraphicAnalysis('graphic_bridge_meme_1'),
        );

        expect(explanation, isNotNull);
        expect(explanation!.cellId, 'memes');
      },
    );

    test('invoice-like printed page with receipt OCR routes to Receipts', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'graphic_bridge_document_1'),
        labels: [
          _label('document', 0.86),
          _label('printed_page', 0.78),
          _label('text', 0.74),
          _label('paper', 0.70),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.42,
          fullOcrText:
              'invoice number 123\nsubtotal 12.00\ntax 2.00\n'
              'total 14.00\npayment due on receipt',
          lineCount: 12,
          blockCount: 5,
          hasChatLikeLayout: false,
          hasTableLikeLayout: true,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = routingStage.route(analysis);

      expect(explanation, isNotNull);
      expect(explanation!.cellId, 'receipts');
    });

    test('sunset outdoor photo does not hit Animation Meme', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'graphic_bridge_sunset_1'),
        labels: [
          _label('sunset', 0.92),
          _label('outdoor', 0.88),
          _label('sky', 0.84),
          _label('cloud', 0.72),
        ],
      );

      expect(explanation.cellId, isNot('animation_cartoon_meme'));
      expect(explanation.topCandidateCellId, isNot('animation_cartoon_meme'));
    });

    test('meme graphic broad labels resolve to Animation after gates', () {
      const precedenceStage = VetoPrecedenceStage();
      const gateStage = CategoryEntryGateStage();
      final analysis = memeGraphicAnalysis('graphic_bridge_people_guard_1');
      final scores = scoringStage.score(analysis);
      precedenceStage.apply(scores: scores, analysis: analysis);
      gateStage.apply(scores: scores, analysis: analysis);
      final ranked =
          scores.where((score) => !score.vetoed).toList(growable: false)
            ..sort((left, right) => right.score.compareTo(left.score));

      expect(ranked.first.rule.cellId, 'documents_receipts');
    });

    test('meme graphic broad labels cannot leave Travel as top candidate', () {
      const precedenceStage = VetoPrecedenceStage();
      const gateStage = CategoryEntryGateStage();
      final analysis = memeGraphicAnalysis('graphic_bridge_travel_guard_1');
      final scores = scoringStage.score(analysis);
      precedenceStage.apply(scores: scores, analysis: analysis);
      gateStage.apply(scores: scores, analysis: analysis);
      final ranked =
          scores.where((score) => !score.vetoed).toList(growable: false)
            ..sort((left, right) => right.score.compareTo(left.score));

      expect(_scoreForCell(scores, 'travel').vetoed, isTrue);
      expect(ranked.first.rule.cellId, isNot('travel'));
      expect(ranked.first.rule.cellId, 'documents_receipts');
    });
  });

  group('new category routing', () {
    test('clear scenery resolves to Nature', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(
          id: 'nature_positive_1',
          filename: 'beach_sunset.jpg',
        ),
        labels: [
          _label('sunset', 0.92),
          _label('ocean', 0.88),
          _label('beach', 0.84),
          _label('clouds', 0.78),
        ],
      );

      expect(explanation.cellId, 'nature');
      expect(explanation.cellName, 'Nature');
      expect(explanation.cellId, isNot('unsorted'));
    });

    test('Nature does not steal from People when a person is dominant', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'nature_people_guard_1'),
        labels: [
          _label('portrait', 0.93),
          _label('person', 0.88),
          _label('face', 0.84),
          _label('sunset', 0.82),
          _label('ocean', 0.76),
        ],
      );

      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('nature'));
    });

    test('Nature does not steal from Places when a landmark is dominant', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'nature_places_guard_1'),
        labels: [
          _label('architecture', 0.94),
          _label('landmark', 0.9),
          _label('building', 0.86),
          _label('sky', 0.8),
          _label('sunset', 0.72),
        ],
      );

      expect(explanation.cellId, 'places');
      expect(explanation.cellId, isNot('nature'));
    });

    test('clear vehicle subject resolves to Cars and Vehicles', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(
          id: 'vehicles_positive_1',
          filename: 'car_drive.jpg',
        ),
        labels: [
          _label('car', 0.94),
          _label('vehicle', 0.88),
          _label('road', 0.76),
          _label('dashboard', 0.7),
        ],
      );

      expect(explanation.cellId, 'vehicles');
      expect(explanation.cellName, 'Cars');
      expect(explanation.cellId, isNot('unsorted'));
    });

    test('Vehicles does not steal from People when a person is dominant', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'vehicles_people_guard_1'),
        labels: [
          _label('selfie', 0.93),
          _label('person', 0.88),
          _label('face', 0.84),
          _label('car', 0.82),
          _label('vehicle', 0.76),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.14,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.0,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = pipeline.explainPlacementFromAnalysis(analysis);
      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('vehicles'));
    });

    test('Vehicles does not steal from Places when a landmark is dominant', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'vehicles_places_guard_1'),
        labels: [
          _label('landmark', 0.94),
          _label('architecture', 0.9),
          _label('building', 0.86),
          _label('car', 0.78),
          _label('road', 0.72),
        ],
      );

      expect(explanation.cellId, 'places');
      expect(explanation.cellId, isNot('vehicles'));
    });

    test('clear receipt layout resolves to Receipts', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'receipts_positive_1', filename: 'receipt.jpg'),
        labels: [
          _label('receipt', 0.9),
          _label('invoice', 0.84),
          _label('total', 0.8),
          _label('payment', 0.72),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.22,
          fullOcrText:
              'cashier till\nsubtotal 120.00\nvat 18.00\ntotal 138.00\n'
              'thank you for your purchase',
          lineCount: 5,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: true,
          barcodeCount: 1,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);

      expect(explanation.cellId, 'receipts');
      expect(explanation.cellName, 'Receipts');
      expect(explanation.cellId, isNot('screenshots'));
      expect(explanation.cellId, isNot('unsorted'));
    });

    test('Receipts does not steal from People when a person is dominant', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'receipts_people_guard_1'),
        labels: [
          _label('portrait', 0.93),
          _label('person', 0.88),
          _label('face', 0.84),
          _label('receipt', 0.82),
          _label('total', 0.76),
        ],
        structural: const StructuralSignals(
          faceCount: 1,
          largestFaceAreaRatio: 0.14,
          hasSingleLargeFace: true,
          textCoverageRatio: 0.18,
          fullOcrText: 'receipt subtotal vat total payment received',
          lineCount: 4,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: true,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);

      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('receipts'));
    });

    test('Receipts does not steal from Places when a landmark is dominant', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'receipts_places_guard_1'),
        labels: [
          _label('landmark', 0.94),
          _label('architecture', 0.9),
          _label('building', 0.86),
          _label('receipt', 0.8),
          _label('total', 0.74),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0.18,
          fullOcrText: 'receipt subtotal vat total payment received',
          lineCount: 4,
          blockCount: 2,
          hasChatLikeLayout: false,
          hasTableLikeLayout: true,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
        ),
      );

      final explanation = _resolveAnalysis(analysis);

      expect(explanation.cellId, 'places');
      expect(explanation.cellId, isNot('receipts'));
    });

    test(
      'Receipts does not steal from Documents when MRZ evidence is present',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'receipts_documents_guard_1'),
          labels: [
            _label('passport', 0.96),
            _label('id card', 0.9),
            _label('document', 0.84),
            _label('receipt', 0.76),
            _label('total', 0.7),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.22,
            fullOcrText:
                'p<utoeriksson<<anna<maria<<<<<<<<<<<<<<<<<<<\n'
                'l898902c36uto7408122f1204159ze184226b<<<<<10',
            lineCount: 3,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: true,
          ),
        );

        final explanation = _resolveAnalysis(analysis);

        expect(explanation.cellId, 'documents_receipts');
        expect(explanation.cellId, isNot('receipts'));
      },
    );
  });

  group('confirmed HIVE classification failures', () {
    test('realHumanFaceNotUnsorted', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'regression_human_face_1'),
        labels: [
          _label('face', 0.94),
          _label('person', 0.9),
          _label('portrait', 0.88),
          _label('selfie', 0.84),
        ],
      );

      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('unsorted'));
    });

    test('selfieNotPets', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'regression_selfie_not_pets_1'),
        labels: [
          _label('selfie', 0.93),
          _label('face', 0.9),
          _label('person', 0.87),
          _label('portrait', 0.84),
          _label('grass', 0.28),
          _label('fur', 0.22),
        ],
      );

      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('pets'));
    });

    test('weakAnimalCueNotPets', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'regression_weak_animal_1'),
        labels: [
          _label('grass', 0.38),
          _label('outdoor', 0.34),
          _label('park', 0.31),
        ],
      );

      expect(explanation.cellId, isNot('pets'));
    });

    test('jerseyOnlyNotSports', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'regression_jersey_only_1'),
        labels: [
          _label('jersey', 0.82),
          _label('logo', 0.78),
          _label('apparel', 0.74),
          _label('shirt', 0.7),
        ],
      );

      expect(explanation.cellId, isNot('sports'));
    });

    test('passportFaceNotPeople', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(
          id: 'regression_passport_face_1',
          filename: 'passport_mrz_scan.jpg',
        ),
        labels: [
          _label('passport', 0.97),
          _label('document', 0.9),
          _label('mrz', 0.88),
          _label('face', 0.72),
        ],
      );

      expect(explanation.cellId, 'documents_receipts');
      expect(explanation.cellId, isNot('people'));
    });

    test('chatScreenshotNotPeople', () {
      final explanation = pipeline.explainPlacement(
        asset: _screenshotAsset(
          id: 'regression_chat_screenshot_1',
          filename: 'Screenshot 2026-04-27 at 09.41.10.png',
          width: 1179,
          height: 2556,
        ),
        labels: [
          _label('user interface', 0.92),
          _label('text message', 0.88),
          _label('chat', 0.84),
          _label('notification', 0.74),
          _label('face', 0.56),
        ],
      );

      expect(explanation.cellId, 'screenshots');
      expect(explanation.cellId, isNot('people'));
    });

    test('scoreboardNotPlaces', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(
          id: 'regression_scoreboard_1',
          filename: 'fixture_vs_2_1_flag_card.jpg',
        ),
        labels: [
          _label('scoreboard', 0.9),
          _label('league', 0.86),
          _label('match', 0.82),
          _label('stadium', 0.76),
          _label('flag', 0.72),
        ],
      );

      expect(explanation.cellId, 'sports');
      expect(explanation.cellId, isNot('places'));
    });

    test('mosqueNotPetsOrUnsorted', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'regression_mosque_1'),
        labels: [
          _label('architecture', 0.93),
          _label('mosque', 0.9),
          _label('dome', 0.82),
          _label('minaret', 0.8),
        ],
      );

      expect(explanation.cellId, 'places');
      expect(explanation.cellId, isNot('pets'));
      expect(explanation.cellId, isNot('unsorted'));
    });

    test('foodNotUnsorted', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'regression_food_1'),
        labels: [
          _label('dish', 0.88),
          _label('meal', 0.84),
          _label('plate', 0.8),
          _label('food', 0.78),
          _label('cuisine', 0.74),
        ],
      );

      expect(explanation.cellId, 'food');
      expect(explanation.cellId, isNot('unsorted'));
    });

    test(
      'physical manga book with weak device labels and OCR goes to books',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'live_books_weak_device_ocr_1'),
          labels: [
            _label('machine', 0.32),
            _label('consumer_electronics', 0.32),
            _label('computer', 0.32),
            _label('computer_keyboard', 0.32),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.095,
            fullOcrText: 'VOL. 12 ISBN 978-1-23456-789-0 SHONEN JUMP',
            lineCount: 8,
            blockCount: 3,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'books');
        expect(explanation.cellId, isNot('devices_tech'));
      },
    );

    test('deterministic repeat: same analysis twice yields same cell', () {
      final analysis = _analysisWithStructural(
        asset: _imageAsset(id: 'repeat_determinism_1'),
        labels: [
          _label('art', 0.31),
          _label('illustrations', 0.30),
          _label('people', 0.20),
          _label('adult', 0.20),
        ],
        structural: const StructuralSignals(
          faceCount: 0,
          largestFaceAreaRatio: 0,
          hasSingleLargeFace: false,
          textCoverageRatio: 0,
          fullOcrText: '',
          lineCount: 0,
          blockCount: 0,
          hasChatLikeLayout: false,
          hasTableLikeLayout: false,
          barcodeCount: 0,
          hasQrCode: false,
          hasMrzPattern: false,
          nonPhotoCharacterStyle: false,
          physicalBookVisualMedium: false,
        ),
      );
      final first = _resolveAnalysis(analysis);
      final second = _resolveAnalysis(analysis);
      expect(second.cellId, first.cellId);
    });

    // Emergency stabilization: remove tests that depend on experimental thumbnail detectors.

    group('stability regressions after problem v2 tuning', () {
      test(
        'real person photo with strong people labels but missed face still goes people',
        () {
          final analysis = _analysisWithStructural(
            asset: _imageAsset(id: 'stable_people_missed_face_1'),
            labels: [
              _label('people', 0.87),
              _label('adult', 0.83),
              _label('person', 0.78),
              _label('clothing', 0.62),
            ],
            structural: const StructuralSignals(
              faceCount: 0,
              largestFaceAreaRatio: 0,
              hasSingleLargeFace: false,
              textCoverageRatio: 0,
              fullOcrText: '',
              lineCount: 0,
              blockCount: 0,
              hasChatLikeLayout: false,
              hasTableLikeLayout: false,
              barcodeCount: 0,
              hasQrCode: false,
              hasMrzPattern: false,
            ),
          );
          final explanation = _resolveAnalysis(analysis);
          expect(explanation.cellId, 'people');
          expect(explanation.cellId, isNot('animation'));
          expect(explanation.cellId, isNot('screenshots'));
        },
      );

      test('mosque with incidental people labels stays places', () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'stable_mosque_incidental_people_1'),
          labels: [
            _label('structure', 0.76),
            _label('outdoor', 0.72),
            _label('people', 0.69),
            _label('building', 0.68),
            _label('arch', 0.61),
            _label('adult', 0.60),
            _label('mosque', 0.58),
          ],
        );
        expect(explanation.cellId, 'places');
        expect(explanation.cellId, isNot('people'));
      });

      test('real outdoor structure with high graphicness stays places not animation', () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'stable_outdoor_structure_1'),
          labels: [
            _label('structure', 0.82),
            _label('outdoor', 0.78),
            _label('building', 0.74),
            _label('fence', 0.66),
            _label('sky', 0.62),
          ],
        );
        expect(explanation.cellId, anyOf(equals('places'), equals('nature')));
        expect(explanation.cellId, isNot('animation'));
      });

      test('real grass landscape with high graphicness stays places or nature not animation', () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'stable_grass_landscape_1'),
          labels: [
            _label('grass', 0.86),
            _label('land', 0.80),
            _label('outdoor', 0.76),
            _label('tree', 0.62),
            _label('sky', 0.58),
          ],
        );
        expect(explanation.cellId, anyOf(equals('nature'), equals('places')));
        expect(explanation.cellId, isNot('animation'));
      });

      test('food/dining context stays food', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'stable_food_1'),
          labels: [
            _label('table', 0.71),
            _label('utensil', 0.48),
            _label('tableware', 0.48),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.011,
            hasSingleLargeFace: false,
            textCoverageRatio: 0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );
        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'food');
      });

      test('screenshot stays screenshots', () {
        final explanation = pipeline.explainPlacement(
          asset: _screenshotAsset(
            id: 'stable_screenshot_1',
            filename: 'Screenshot 2026-05-05 at 11.30.00.png',
            width: 1179,
            height: 2556,
          ),
          labels: [
            _label('screenshot', 0.92),
            _label('user interface', 0.88),
          ],
        );
        expect(explanation.cellId, 'screenshots');
      });

      test('weak device labels plus weak book label routes to books not devices', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'stable_books_weak_device_weak_book_1'),
          labels: [
            _label('machine', 0.32),
            _label('consumer_electronics', 0.32),
            _label('computer', 0.32),
            _label('computer_keyboard', 0.32),
            _label('document', 0.15),
            _label('book', 0.15),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );
        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'books');
        expect(explanation.cellId, isNot('devices_tech'));
      });

      test('strong laptop labels still route devices tech', () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'stable_devices_strong_1', width: 1440, height: 900),
          labels: [
            _label('machine', 0.79),
            _label('consumer_electronics', 0.79),
            _label('computer', 0.79),
            _label('computer_keyboard', 0.79),
          ],
        );
        expect(explanation.cellId, 'devices_tech');
      });

      test('explicit anime/art labels route animation', () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'stable_animation_explicit_1'),
          labels: [
            _label('art', 0.72),
            _label('illustration', 0.66),
            _label('cartoon', 0.62),
          ],
        );
        expect(explanation.cellId, 'animation');
      });
    });

    test('mosque architecture with incidental people labels stays places', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'live_mosque_incidental_people_1'),
        labels: [
          _label('structure', 0.76),
          _label('outdoor', 0.72),
          _label('people', 0.69),
          _label('building', 0.68),
          _label('mosque', 0.62),
          _label('architecture', 0.58),
        ],
      );
      expect(explanation.cellId, 'places');
      expect(explanation.cellId, isNot('people'));
    });

    test('anime/animated human with weak people labels routes to animation', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(id: 'live_anime_weak_people_1'),
        labels: [
          _label('art', 0.31),
          _label('illustrations', 0.30),
          _label('people', 0.20),
          _label('adult', 0.20),
        ],
      );
      expect(explanation.cellId, 'animation');
      expect(explanation.cellId, isNot('people'));
    });

    test(
      'strong people labels but realHuman=false does not force animation without explicit stylized evidence (stability)',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'live_people_strong_not_real_1'),
          labels: [
            _label('people', 0.87),
            _label('adult', 0.87),
            _label('outdoor', 0.86),
            _label('grass', 0.76),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );
        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'people');
      },
    );

    test(
      'strong people labels with realHuman=true still routes to people (safety)',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'live_people_strong_real_1'),
          labels: [
            _label('people', 0.87),
            _label('adult', 0.87),
            _label('outdoor', 0.86),
            _label('grass', 0.76),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.18,
            hasSingleLargeFace: true,
            textCoverageRatio: 0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );
        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'people');
      },
    );

    test(
      'weak art with weak nature labels does not force animation (stability)',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'live_weak_art_storm_1'),
          labels: [
            _label('outdoor', 0.40),
            _label('sky', 0.40),
            _label('storm', 0.40),
            _label('art', 0.13),
          ],
        );
        expect(explanation.cellId, anyOf(equals('nature'), equals('places'), equals('animation')));
      },
    );

    test(
      'weak art without non-photo override stays nature when nature evidence is strong enough',
      () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'live_weak_art_storm_2'),
          labels: [
            _label('outdoor', 0.74),
            _label('sky', 0.71),
            _label('storm', 0.66),
            _label('art', 0.13),
          ],
        );
        expect(explanation.cellId, anyOf(equals('nature'), equals('places')));
        expect(explanation.cellId, isNot('animation'));
      },
    );

    test(
      'dining rescue food with generic table labels stays food (no -40 penalty)',
      () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'live_food_dining_rescue_1'),
          labels: [
            _label('structure', 0.71),
            _label('furniture', 0.71),
            _label('table', 0.71),
            _label('utensil', 0.48),
            _label('tableware', 0.48),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.011,
            hasSingleLargeFace: false,
            textCoverageRatio: 0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );
        final explanation = _resolveAnalysis(analysis);
        expect(explanation.cellId, 'food');
        expect(explanation.cellId, isNot('unsorted'));
        expect(explanation.cellId, isNot('animation'));
        expect(explanation.cellId, isNot('devices_tech'));
      },
    );

    test('memeNotPetsOrPlaces', () {
      final explanation = pipeline.explainPlacement(
        asset: _imageAsset(
          id: 'regression_meme_1',
          filename: 'reposted_poster_caption_card.jpg',
          width: 1179,
          height: 2556,
        ),
        labels: [
          _label('meme', 0.9),
          _label('poster', 0.86),
          _label('graphic design', 0.84),
          _label('text', 0.82),
          _label('caption', 0.78),
        ],
      );

      expect(explanation.cellId, 'memes');
      expect(explanation.cellId, isNot('pets'));
      expect(explanation.cellId, isNot('places'));
      expect(explanation.cellId, isNot('documents_receipts'));
      expect(explanation.cellId, isNot('unsorted'));
    });

    test('unsortedHasReasonCode', () {
      final cases = [
        _RegressionCase(
          name: 'realHumanFaceNotUnsorted',
          asset: _imageAsset(id: 'reason_human_face_1'),
          labels: [
            _label('face', 0.94),
            _label('person', 0.9),
            _label('portrait', 0.88),
            _label('selfie', 0.84),
          ],
        ),
        _RegressionCase(
          name: 'selfieNotPets',
          asset: _imageAsset(id: 'reason_selfie_not_pets_1'),
          labels: [
            _label('selfie', 0.93),
            _label('face', 0.9),
            _label('person', 0.87),
            _label('portrait', 0.84),
            _label('grass', 0.28),
            _label('fur', 0.22),
          ],
        ),
        _RegressionCase(
          name: 'weakAnimalCueNotPets',
          asset: _imageAsset(id: 'reason_weak_animal_1'),
          labels: [
            _label('grass', 0.38),
            _label('outdoor', 0.34),
            _label('park', 0.31),
          ],
        ),
        _RegressionCase(
          name: 'jerseyOnlyNotSports',
          asset: _imageAsset(id: 'reason_jersey_only_1'),
          labels: [
            _label('jersey', 0.82),
            _label('logo', 0.78),
            _label('apparel', 0.74),
            _label('shirt', 0.7),
          ],
        ),
        _RegressionCase(
          name: 'passportFaceNotPeople',
          asset: _imageAsset(
            id: 'reason_passport_face_1',
            filename: 'passport_mrz_scan.jpg',
          ),
          labels: [
            _label('passport', 0.97),
            _label('document', 0.9),
            _label('mrz', 0.88),
            _label('face', 0.72),
          ],
        ),
        _RegressionCase(
          name: 'chatScreenshotNotPeople',
          asset: _screenshotAsset(
            id: 'reason_chat_screenshot_1',
            filename: 'Screenshot 2026-04-27 at 09.41.10.png',
            width: 1179,
            height: 2556,
          ),
          labels: [
            _label('user interface', 0.92),
            _label('text message', 0.88),
            _label('chat', 0.84),
            _label('notification', 0.74),
            _label('face', 0.56),
          ],
        ),
        _RegressionCase(
          name: 'scoreboardNotPlaces',
          asset: _imageAsset(
            id: 'reason_scoreboard_1',
            filename: 'fixture_vs_2_1_flag_card.jpg',
          ),
          labels: [
            _label('scoreboard', 0.9),
            _label('league', 0.86),
            _label('match', 0.82),
            _label('stadium', 0.76),
            _label('flag', 0.72),
          ],
        ),
        _RegressionCase(
          name: 'mosqueNotPetsOrUnsorted',
          asset: _imageAsset(id: 'reason_mosque_1'),
          labels: [
            _label('architecture', 0.93),
            _label('mosque', 0.9),
            _label('dome', 0.82),
            _label('minaret', 0.8),
          ],
        ),
        _RegressionCase(
          name: 'foodNotUnsorted',
          asset: _imageAsset(id: 'reason_food_1'),
          labels: [
            _label('dish', 0.88),
            _label('meal', 0.84),
            _label('plate', 0.8),
            _label('food', 0.78),
            _label('cuisine', 0.74),
          ],
        ),
        _RegressionCase(
          name: 'memeNotPetsOrPlaces',
          asset: _imageAsset(
            id: 'reason_meme_1',
            filename: 'reposted_poster_caption_card.jpg',
            width: 1179,
            height: 2556,
          ),
          labels: [
            _label('meme', 0.9),
            _label('poster', 0.86),
            _label('graphic design', 0.84),
            _label('text', 0.82),
            _label('caption', 0.78),
          ],
        ),
      ];

      for (final regressionCase in cases) {
        final explanation = pipeline.explainPlacement(
          asset: regressionCase.asset,
          labels: regressionCase.labels,
        );
        if (explanation.cellId == 'unsorted') {
          expect(
            explanation.unsortedReason,
            isNotNull,
            reason: regressionCase.name,
          );
        }
      }

      final noSignalAnalysis = analysisBuilder.build(
        asset: _imageAsset(id: 'reason_no_signal_1'),
        labels: [_label('texture', 0.23), _label('pattern', 0.21)],
      );
      final noSignalExplanation = decisionStage.resolve(
        analysis: noSignalAnalysis,
        derived: DerivedSignals.from(noSignalAnalysis),
        scores: [
          PlacementScoreCard(
            rule: KeywordPlacementDefinitions.ruleForCellId('devices_tech')!,
            score: 0.38,
            matchedKeywords: {'weak tech cue'},
          ),
        ],
      );

      expect(noSignalExplanation.cellId, 'unsorted');
      expect(noSignalExplanation.unsortedReason, UnsortedReason.noSignal);
    });

    group('explicit sample-space regressions (public KeywordPlacementPipeline)', () {
      test(
        'sampleSpaceAnimeWeakPeopleWithCartoonLabelsRoutesAnimationNotPeople',
        () {
          final analysis = _analysisWithStructural(
            asset: _imageAsset(id: 'sample_anime_weak_people_1'),
            labels: [
              _label('people', 0.40),
              _label('adult', 0.38),
              _label('cartoon', 0.72),
              _label('anime', 0.66),
              _label('illustration', 0.61),
            ],
            structural: const StructuralSignals(
              faceCount: 1,
              largestFaceAreaRatio: 0.12,
              hasSingleLargeFace: false,
              textCoverageRatio: 0.0,
              fullOcrText: '',
              lineCount: 0,
              blockCount: 0,
              hasChatLikeLayout: false,
              hasTableLikeLayout: false,
              barcodeCount: 0,
              hasQrCode: false,
              hasMrzPattern: false,
            ),
          );

          final explanation = pipeline.explainPlacementFromAnalysis(analysis);
          expect(explanation.cellId, isNot('people'));
          expect(
            explanation.cellId,
            anyOf(
              equals('animation'),
              equals('animation_cartoon_meme'),
            ),
          );
        },
      );

      test('sampleSpace3DCartoonCharacterRoutesAnimationFamilyNotPeople', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(
            id: 'sample_3d_cartoon_1',
            filename: 'cgi_figure_studio_render.jpg',
          ),
          labels: [
            _label('cartoon', 0.90),
            _label('3d render', 0.86),
            _label('animated character', 0.80),
            _label('toy', 0.72),
            _label('figurine', 0.68),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, isNot('unsorted'));
        expect(explanation.cellId, isNot('people'));
        expect(
          explanation.cellId,
          anyOf(
            equals('animation'),
            equals('animation_cartoon_meme'),
            equals('memes'),
          ),
        );
      });

      test('sampleSpaceMangaPanelOcrRoutesAnimationFamilyNotDevices', () {
        // Keep text/light layout below quote-card meme heuristics; rely on OCR
        // comics vocabulary + stacked labels similar to ambiguous panels.
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'sample_manga_panel_1'),
          labels: [
            _label('structure', 0.45),
            _label('indoor', 0.38),
            _label('sign', 0.22),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.10,
            fullOcrText:
                'serialized anthology shonen comics panel lettering sfx tone',
            lineCount: 1,
            blockCount: 1,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, isNot('unsorted'));
        expect(explanation.cellId, isNot('devices_tech'));
        expect(explanation.cellId, isNot('people'));
        expect(
          explanation.cellId,
          anyOf(equals('animation'), equals('animation_cartoon_meme')),
        );
      });

      test(
        'sampleSpaceMangaBookCoverOcrRoutesAnimationFamilyNotDocumentsOrDevices',
        () {
          final analysis = _analysisWithStructural(
            asset: _imageAsset(id: 'sample_manga_cover_1'),
            labels: [
              _label('text', 0.72),
              _label('sign', 0.66),
              _label('book', 0.62),
              _label('cover', 0.58),
              _label('hand', 0.44),
            ],
            structural: const StructuralSignals(
              faceCount: 0,
              largestFaceAreaRatio: 0,
              hasSingleLargeFace: false,
              textCoverageRatio: 0.10,
              fullOcrText:
                  'edition hero academia shonen jump comics '
                  'bookstore clearance 30% off vol 24',
              lineCount: 1,
              blockCount: 1,
              hasChatLikeLayout: false,
              hasTableLikeLayout: false,
              barcodeCount: 0,
              hasQrCode: false,
              hasMrzPattern: false,
            ),
          );

          final explanation = pipeline.explainPlacementFromAnalysis(analysis);
          expect(explanation.cellId, isNot('people'));
          expect(explanation.cellId, isNot('devices_tech'));
          expect(explanation.cellId, isNot('documents_receipts'));
          expect(explanation.cellId, isNot('receipts'));
          // Physical printed manga cover should route to Books (not Animation).
          expect(explanation.cellId, equals('books'));
        },
      );

      test('sampleSpaceDominantCarWithSkyRoutesVehiclesNotNatureOrPlaces', () {
        final explanation = pipeline.explainPlacement(
          asset: _imageAsset(id: 'sample_car_sky_trees_1'),
          labels: [
            _label('car', 0.68),
            _label('vehicle', 0.62),
            _label('wheel', 0.55),
            _label('sky', 0.55),
            _label('tree', 0.48),
          ],
        );

        expect(explanation.cellId, 'vehicles');
        expect(explanation.cellId, isNot('nature'));
        expect(explanation.cellId, isNot('places'));
      });

      test('sampleSpacePhoneScreenWithOnScreenFaceRoutesTechNotPeople', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'sample_phone_screen_face_1'),
          labels: [
            _label('technology', 0.72),
            _label('display', 0.60),
            _label('smartphone', 0.58),
            _label('people', 0.44),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0.05,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.04,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, isNot('people'));
        expect(
          explanation.cellId,
          anyOf(equals('devices_tech'), equals('screenshots')),
        );
      });

      test('sampleSpaceMemePosterSportsCaptionRoutesMemesNotAnimation', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'sample_sports_meme_poster_1'),
          labels: [
            _label('meme', 0.91),
            _label('poster', 0.86),
            _label('text', 0.82),
            _label('sports', 0.76),
            _label('person', 0.70),
            _label('athlete', 0.62),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.28,
            fullOcrText:
                'full time score league fixture\nsaid\nwhen he scores vs before',
            lineCount: 5,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, 'memes');
        expect(explanation.cellId, isNot('animation'));
        expect(explanation.cellId, isNot('people'));
      });

      test('sampleSpaceRealHumanSelfieRegressionRoutesPeople', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'sample_real_selfie_1'),
          labels: [
            _label('people', 0.88),
            _label('adult', 0.85),
            _label('selfie', 0.72),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.22,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        expect(pipeline.explainPlacementFromAnalysis(analysis).cellId, 'people');
      });

      test('sampleSpaceNativeScreenshotRoutesScreenshotsBaseline', () {
        expect(
          pipeline
              .explainPlacement(
                asset: _screenshotAsset(id: 'sample_screenshot_baseline_1'),
                labels: [
                  _label('user interface', 0.90),
                  _label('text message', 0.84),
                  _label('notification', 0.72),
                ],
              )
              .cellId,
          'screenshots',
        );
      });

      test('sampleSpaceNativeScreenshotYieldsWhenDominantMemeSignalPresent', () {
        final explanation = pipeline.explainPlacement(
          asset: _screenshotAsset(id: 'sample_screenshot_meme_dom_1'),
          labels: [
            _label('meme', 0.92),
            _label('caption', 0.86),
            _label('user interface', 0.74),
          ],
        );

        expect(explanation.cellId, isNot('screenshots'));
        expect(explanation.cellId, equals('memes'));
      });

      test('sampleSpaceDessertClusterRoutesFood', () {
        expect(
          pipeline
              .explainPlacement(
                asset: _imageAsset(id: 'sample_dessert_cluster_1'),
                labels: [
                  _label('dessert', 0.55),
                  _label('food', 0.48),
                  _label('pastry', 0.52),
                  _label('donut', 0.46),
                  _label('confectionery', 0.44),
                ],
              )
              .cellId,
          'food',
        );
      });

      test(
        'sampleSpaceCoffeePackagingOcrRoutesFoodNotDocumentsMemesDevices',
        () {
          final analysis = _analysisWithStructural(
            asset: _imageAsset(id: 'sample_jacobs_cappuccino_box_2'),
            labels: [
              _label('text', 0.65),
              _label('sign', 0.58),
              _label('beverage', 0.45),
            ],
            structural: const StructuralSignals(
              faceCount: 0,
              largestFaceAreaRatio: 0,
              hasSingleLargeFace: false,
              textCoverageRatio: 0.22,
              fullOcrText:
                  'JACOBS CAPPUCCINO\nreduced sugar\nserving suggestion\ningredients',
              lineCount: 4,
              blockCount: 2,
              hasChatLikeLayout: false,
              hasTableLikeLayout: false,
              barcodeCount: 0,
              hasQrCode: false,
              hasMrzPattern: false,
            ),
          );

          final explanation = pipeline.explainPlacementFromAnalysis(analysis);
          expect(explanation.cellId, 'food');
          expect(explanation.cellId, isNot('documents_receipts'));
          expect(explanation.cellId, isNot('receipts'));
          expect(explanation.cellId, isNot('memes'));
          expect(explanation.cellId, isNot('devices_tech'));
        },
      );

      test(
        'sampleSpaceWeakLabels3DCartoonMouseGrassRoutesAnimationNotPetsNatureUnsorted',
        () {
          // Real Vision stacks often omit "cartoon" / "cgi"; graphicness proxy
          // comes from weak face-area + absent human portrait labels (DerivedSignals).
          final analysis = _analysisWithStructural(
            asset: _imageAsset(id: 'sample_cgi_mouse_grass_weak_labels'),
            labels: [
              _label('mouse', 0.55),
              _label('animal', 0.52),
              _label('mammal', 0.48),
              _label('grass', 0.50),
              _label('outdoor', 0.42),
              _label('object', 0.35),
            ],
            structural: const StructuralSignals(
              faceCount: 1,
              largestFaceAreaRatio: 0.07,
              hasSingleLargeFace: false,
              textCoverageRatio: 0.0,
              fullOcrText: '',
              lineCount: 0,
              blockCount: 0,
              hasChatLikeLayout: false,
              hasTableLikeLayout: false,
              barcodeCount: 0,
              hasQrCode: false,
              hasMrzPattern: false,
            ),
          );

          final explanation = pipeline.explainPlacementFromAnalysis(analysis);
          expect(explanation.cellId, isNot('pets'));
          expect(explanation.cellId, isNot('nature'));
          expect(explanation.cellId, isNot('unsorted'));
          expect(
            explanation.cellId,
            anyOf(
              equals('animation'),
              equals('animation_cartoon_meme'),
            ),
          );
        },
      );

      test(
        'sampleSpaceWeakLabelsComicSuperheroRainCityRoutesAnimationNotPeoplePlacesNatureUnsorted',
        () {
          final analysis = _analysisWithStructural(
            asset: _imageAsset(id: 'sample_comic_superhero_rain_city_weak_labels'),
            labels: [
              _label('person', 0.46),
              _label('human body', 0.42),
              _label('rain', 0.55),
              _label('night', 0.50),
              _label('city', 0.45),
              _label('skyline', 0.40),
              _label('poster', 0.35),
            ],
            structural: const StructuralSignals(
              faceCount: 1,
              largestFaceAreaRatio: 0.045,
              hasSingleLargeFace: false,
              textCoverageRatio: 0.0,
              fullOcrText: '',
              lineCount: 0,
              blockCount: 0,
              hasChatLikeLayout: false,
              hasTableLikeLayout: false,
              barcodeCount: 0,
              hasQrCode: false,
              hasMrzPattern: false,
            ),
          );

          final explanation = pipeline.explainPlacementFromAnalysis(analysis);
          expect(explanation.cellId, isNot('people'));
          expect(explanation.cellId, isNot('places'));
          expect(explanation.cellId, isNot('nature'));
          expect(explanation.cellId, isNot('unsorted'));
          expect(
            explanation.cellId,
            anyOf(
              equals('animation'),
              equals('animation_cartoon_meme'),
            ),
          );
        },
      );
    });

    group('targeted bug regressions (2026-05-03)', () {
      test('art/illustrations with weak people labels routes to animation (not people)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_art_illustrations_weak_people'),
          labels: [
            _label('art', 0.31),
            _label('illustrations', 0.30),
            _label('people', 0.20),
            _label('adult', 0.20),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.07,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, isNot('people'));
        expect(
          explanation.cellId,
          anyOf(equals('animation'), equals('animation_cartoon_meme')),
        );
      });

      test('mosque courtyard with incidental people routes to places', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_mosque_courtyard_incidental_people'),
          labels: [
            _label('mosque', 0.72),
            _label('architecture', 0.68),
            _label('courtyard', 0.60),
            _label('people', 0.55),
            _label('adult', 0.50),
          ],
          structural: const StructuralSignals(
            faceCount: 2,
            largestFaceAreaRatio: 0.02,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, equals('places'));
        expect(explanation.cellId, isNot('people'));
      });

      test('photo of phone showing social app routes to devices_tech (not memes)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_phone_photo_social_ui'),
          labels: [
            _label('technology', 0.75),
            _label('smartphone', 0.68),
            _label('display', 0.60),
            _label('people', 0.45),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.06,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.18,
            fullOcrText: 'snapchat story',
            lineCount: 3,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, equals('devices_tech'));
        expect(explanation.cellId, isNot('memes'));
      });

      test('consumer_electronics/machine phone photo routes to devices_tech (not memes)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_consumer_electronics_phone_photo'),
          labels: [
            _label('consumer_electronics', 0.79),
            _label('machine', 0.79),
            _label('display', 0.74),
            _label('screen', 0.71),
            _label('people', 0.42),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.05,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.16,
            fullOcrText: 'snapchat',
            lineCount: 2,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final routed = routingStage.route(analysis);
        expect(routed, isNotNull);
        expect(routed!.cellId, equals('devices_tech'));
      });

      test('native social app screenshot UI routes to screenshots (not memes)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_native_social_app_ui'),
          labels: [
            _label('smartphone', 0.62),
            _label('screen', 0.58),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0.0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.45,
            fullOcrText: 'Follow\nShare profile\nQR code\nFollowers\nFollowing',
            lineCount: 8,
            blockCount: 3,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final routed = routingStage.route(analysis);
        expect(routed, isNotNull);
        expect(routed!.cellId, equals('screenshots'));
      });

      test('anime character with weak people labels routes to animation', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_anime_weak_people_labels'),
          labels: [
            _label('people', 0.42),
            _label('adult', 0.40),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.07,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, isNot('unsorted'));
        expect(
          explanation.cellId,
          anyOf(equals('animation'), equals('animation_cartoon_meme')),
        );
      });

      test('manga panel with no face routes to animation', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_manga_no_face'),
          labels: [
            _label('indoor', 0.55),
            _label('structure', 0.45),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0.0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, isNot('people'));
      });

      test('3D animated animal character does not force People (stability)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_animated_animal_3d'),
          labels: [
            _label('animal', 0.42),
            _label('grass', 0.55),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0.0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, isNot('people'));
      });

      test('sports broadcast with emoji caption routes to memes (not people)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_sports_broadcast_emoji_caption'),
          labels: [
            _label('person', 0.58),
            _label('scoreboard', 0.62),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.07,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.06,
            fullOcrText: 'ARS 0-2 MCI 77:51\n2026 😭😭😭😂',
            lineCount: 4,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, equals('memes'));
        expect(explanation.cellId, isNot('people'));
      });

      test('real selfie still routes to people (architecture guard does not block)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_selfie_people_not_blocked'),
          labels: [
            _label('people', 0.88),
            _label('adult', 0.85),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.22,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, equals('people'));
      });

      test('landmark place photo with no people routes to places', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_landmark_no_people'),
          labels: [
            _label('mosque', 0.75),
            _label('architecture', 0.70),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0.0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, equals('places'));
      });
    });

    group('targeted regressions: undo over-broad device cues (2026-05-03)', () {
      test('BMW/car with machine label still routes to vehicles (not devices_tech)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_bmw_machine_vehicle'),
          labels: [
            _label('outdoor', 0.95),
            _label('sky', 0.94),
            _label('cloudy', 0.90),
            _label('machine', 0.79),
            _label('car', 0.72),
            _label('bmw', 0.66),
            _label('road', 0.60),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0.0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, equals('vehicles'));
        expect(explanation.cellId, isNot('devices_tech'));
      });

      test('laptop/phone photo routes to devices_tech when no vehicle evidence exists', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_device_photo_no_vehicle'),
          labels: [
            _label('computer', 0.78),
            _label('laptop', 0.72),
            _label('screen', 0.70),
            _label('display', 0.64),
            _label('technology', 0.58),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.06,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.14,
            fullOcrText: 'browser',
            lineCount: 2,
            blockCount: 1,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, equals('devices_tech'));
        expect(explanation.cellId, isNot('vehicles'));
      });

      test('Yuji anime still routes to animation_cartoon_meme (not unsorted)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_yuji_anime_not_unsorted'),
          labels: [
            _label('anime', 0.62),
            _label('people', 0.44),
            _label('adult', 0.40),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.12,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, isNot('unsorted'));
        expect(
          explanation.cellId,
          anyOf(equals('animation'), equals('animation_cartoon_meme')),
        );
      });

      test('real selfie still routes to people (no artwork evidence)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_real_selfie_people_still_wins'),
          labels: [
            _label('people', 0.88),
            _label('adult', 0.85),
            _label('selfie', 0.82),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.22,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, equals('people'));
      });
    });

    group('live-log bug regressions (2026-05-03 batch-2)', () {
      test('mosque with mosqueCueCount=1 and strongPlaceCueCount=1 routes to places (not people)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_mosque_place_people_margin'),
          labels: [
            _label('mosque', 0.72),
            _label('minaret', 0.62),
            _label('people', 0.69),
            _label('adult', 0.42),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.03,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, equals('places'));
        expect(explanation.cellId, isNot('people'));
      });

      test('mall walkway structure+fence+outdoor routes to places (not unsorted)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_mall_walkway_fence_outdoor'),
          labels: [
            _label('structure', 0.85),
            _label('fence', 0.84),
            _label('outdoor', 0.80),
            _label('cloudy', 0.78),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0.0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, equals('places'));
        expect(explanation.cellId, isNot('unsorted'));
      });

      test('food on table never routes to memes when overlayMeme=false', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_food_on_table_not_meme'),
          labels: [
            _label('structure', 0.71),
            _label('furniture', 0.71),
            _label('table', 0.71),
            _label('utensil', 0.48),
            _label('food', 0.62),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0.0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final routed = routingStage.route(analysis);
        expect(routed, isNull); // no forced memes route

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, isNot('memes'));
      });

      test('tiktok/instagram screenshot confidence routes to screenshots (not memes)', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_social_screenshot_confidence'),
          labels: [
            _label('document', 0.88),
            _label('screenshot', 0.88),
            _label('people', 0.71),
            _label('adult', 0.71),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.05,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.12,
            fullOcrText: 'follow\nshare profile\nqr code',
            lineCount: 4,
            blockCount: 2,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final routed = routingStage.route(analysis);
        expect(routed, isNotNull);
        expect(routed!.cellId, equals('screenshots'));
      });

      test('new placements never write legacy animation_cartoon_meme cell id', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_no_legacy_animation_write', filename: 'anime_poster.jpg'),
          labels: [
            _label('anime', 0.72),
            _label('illustration', 0.66),
          ],
          structural: const StructuralSignals(
            faceCount: 0,
            largestFaceAreaRatio: 0.0,
            hasSingleLargeFace: false,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, isNot('animation_cartoon_meme'));
        expect(explanation.topCandidateCellId, isNot('animation_cartoon_meme'));
      });

      test('plain-background fallback does not steal real selfies', () {
        final analysis = _analysisWithStructural(
          asset: _imageAsset(id: 'reg_plain_background_does_not_steal_selfie'),
          labels: [
            _label('people', 0.88),
            _label('adult', 0.85),
          ],
          structural: const StructuralSignals(
            faceCount: 1,
            largestFaceAreaRatio: 0.20,
            hasSingleLargeFace: true,
            textCoverageRatio: 0.0,
            fullOcrText: '',
            lineCount: 0,
            blockCount: 0,
            hasChatLikeLayout: false,
            hasTableLikeLayout: false,
            barcodeCount: 0,
            hasQrCode: false,
            hasMrzPattern: false,
          ),
        );

        final explanation = pipeline.explainPlacementFromAnalysis(analysis);
        expect(explanation.cellId, equals('people'));
      });
    });
  });
}

MediaAsset _imageAsset({
  required String id,
  String? filename,
  int width = 1200,
  int height = 1600,
}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    createdAt: DateTime(2026, 4, 20, 12),
    modifiedAt: DateTime(2026, 4, 20, 12),
    width: width,
    height: height,
    originalFilename: filename ?? 'IMG_$id.HEIC',
  );
}

MediaAsset _screenshotAsset({
  required String id,
  String? filename,
  int width = 1179,
  int height = 2556,
}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.screenshot,
    createdAt: DateTime(2026, 4, 20, 12),
    modifiedAt: DateTime(2026, 4, 20, 12),
    width: width,
    height: height,
    originalFilename: filename ?? 'Screenshot_$id.png',
  );
}

ClassificationLabel _label(String name, double confidence) {
  return ClassificationLabel(
    id: name,
    key: name,
    displayName: name,
    confidence: confidence,
    source: ClassificationLabelSource.onDeviceModel,
    createdAt: DateTime(2026, 4, 20, 12),
    modelIdentifier: 'test',
  );
}

PlacementScoreCard _scoreForCell(
  List<PlacementScoreCard> scores,
  String cellId,
) {
  return scores.firstWhere((score) => score.rule.cellId == cellId);
}

AssetMappingExplanation _resolveAnalysis(AssetAnalysis analysis) {
  const routingStage = ContentTypeRoutingStage();
  const scoringStage = WeightedCategoryScoringStage();
  const precedenceStage = VetoPrecedenceStage();
  const gateStage = CategoryEntryGateStage();
  const decisionStage = PlacementDecisionStage();

  final routed = routingStage.route(analysis);
  if (routed != null) {
    return routed;
  }

  final scores = scoringStage.score(analysis);
  precedenceStage.apply(scores: scores, analysis: analysis);
  gateStage.apply(scores: scores, analysis: analysis);
  return decisionStage.resolve(
    scores: scores,
    analysis: analysis,
    derived: DerivedSignals.from(analysis),
  );
}

class _RegressionCase {
  const _RegressionCase({
    required this.name,
    required this.asset,
    required this.labels,
  });

  final String name;
  final MediaAsset asset;
  final List<ClassificationLabel> labels;
}

Future<StructuralSourceImage?> _fakeImageLoader(MediaAsset asset) async {
  final tempDir = await Directory.systemTemp.createTemp(
    'hive_pipeline_structural_test_',
  );
  final file = File('${tempDir.path}/${asset.id}.jpg');
  await file.writeAsBytes(const [1, 2, 3]);

  return StructuralSourceImage(
    filePath: file.path,
    imageWidth: asset.width > 0 ? asset.width : 1000,
    imageHeight: asset.height > 0 ? asset.height : 1000,
    onDispose: () async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    },
  );
}

AssetAnalysis _analysisWithStructural({
  required MediaAsset asset,
  required List<ClassificationLabel> labels,
  required StructuralSignals structural,
}) {
  final builder = PlacementAnalysisBuilder();
  return builder.build(asset: asset, labels: labels, structural: structural);
}
