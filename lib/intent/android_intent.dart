import 'package:uuid/uuid.dart';
import 'package:luia/models/wish_item.dart';

const _regexPattern = r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+';
final _regex = RegExp(
    _regexPattern,
    caseSensitive: false
  );

WishItem? getWishItemFromMap(Map<String, dynamic>? jsonData) {
  if (jsonData == null) return null;

  var url = '';
  var name = '';
  String? text = jsonData['android.intent.extra.TEXT'] as String?;
  if(jsonData['url'] != null) {
    url = jsonData['url'];
    name = text?? '';
  } else if(text != null  && _hasUrl(text)) {
    url = _extractUrl(text);
    name = text.replaceAll(_regex, '').trim();
  } else {
    name = text ?? '';
  }

  return WishItem(
    id: const Uuid().v4(),
    name: name,
    productUrl:  url,
  );
}

bool _hasUrl(String str) {
  return _regex.hasMatch(str);
}

String _extractUrl(String text) {
  final match = _regex.firstMatch(text);
  return match?.group(0) ?? '';
}