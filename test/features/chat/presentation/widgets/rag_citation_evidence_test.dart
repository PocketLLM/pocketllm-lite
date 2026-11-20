import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/chat/presentation/widgets/rag_citation_evidence.dart';

void main() {
  testWidgets('renders source chip and opens the exact retrieved snippet',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RagCitationEvidence(
            hasRetrievedSources: true,
            citations: [
              {
                'filename': 'Evidence.pdf',
                'page': 2,
                'snippet': 'The exact supporting passage.',
              },
            ],
          ),
        ),
      ),
    );

    expect(find.text('Retrieved context available'), findsOneWidget);
    expect(find.text('Source 1'), findsOneWidget);

    await tester.tap(find.text('Source 1'));
    await tester.pumpAndSettle();

    expect(find.text('Evidence.pdf'), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('The exact supporting passage.'), findsOneWidget);
  });

  testWidgets('shows an ungrounded retrieval state without source chips',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RagCitationEvidence(
            hasRetrievedSources: false,
            citations: [],
          ),
        ),
      ),
    );

    expect(find.text('No supporting sources retrieved'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('does not show retrieval status when RAG was not used',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RagCitationEvidence(
            hasRetrievedSources: null,
            citations: [],
          ),
        ),
      ),
    );

    expect(find.text('Retrieved context available'), findsNothing);
    expect(find.text('No supporting sources retrieved'), findsNothing);
  });
}
