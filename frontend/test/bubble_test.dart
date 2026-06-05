import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/premium_chat_bubble.dart';

void main() {
  testWidgets('Test final ChatScreen and PremiumChatBubble integration', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: ListView.builder(
              itemCount: 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const PremiumChatBubble(
                    message: 'Short msg',
                    isMe: true,
                    time: '12:34',
                  );
                } else {
                  return const PremiumChatBubble(
                    message: 'This is a much longer message that should wrap and size itself properly up to the maxWidth constraint of the bubble.',
                    isMe: false,
                    time: '12:35',
                  );
                }
              },
            ),
          ),
        ),
      ),
    );

    final chatBubbles = find.byType(PremiumChatBubble);
    expect(chatBubbles, findsNWidgets(2));

    // Retrieve render boxes
    final RenderBox firstBubble = tester.renderObject(chatBubbles.at(0));
    final RenderBox secondBubble = tester.renderObject(chatBubbles.at(1));

    // The containers are inside PremiumChatBubble -> Padding -> Align -> Container
    final containerFinder = find.descendant(
      of: chatBubbles,
      matching: find.byType(Container),
    );

    final RenderBox firstContainer = tester.renderObject(containerFinder.at(0));
    final RenderBox secondContainer = tester.renderObject(containerFinder.at(1));

    print('First bubble container size: ${firstContainer.size}');
    print('Second bubble container size: ${secondContainer.size}');

    // The first one should be smaller than 384 width
    expect(firstContainer.size.width, lessThan(384));
    // The second one should wrap and be exactly 384 width (max available width)
    expect(secondContainer.size.width, equals(384));

    // Verify text exists and is visible
    expect(find.text('Short msg'), findsOneWidget);
    expect(find.textContaining('much longer message'), findsOneWidget);
  });
}
