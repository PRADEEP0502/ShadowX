class MockChatService {
  static final Map<String, List<String>> _messagesByUser = {
    'Kumar': ['Hi Kumar 👋', 'How is your day going?', 'Want to chat later?'],
    'Rahul': ['Rahul here ✅', 'Send me the details.'],
    'Arun': ['Arun: let’s build something cool.'],
    'Vicky': ['Vicky: what’s up?'],
  };

  static List<String> messagesFor(String userName) {
    return List<String>.from(_messagesByUser[userName] ?? const []);
  }
}
