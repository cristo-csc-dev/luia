class MessageUtils {

  static String _message = '';

  static void setMessage(String message) {
    _message = message;
  }

  static bool hasMessage() {
    return _message.isNotEmpty;
  }

  static String getMessage() {
    String result = _message;
    _message = '';
    return result;
  }
}