/// Links to shared cocktails.
///
/// GoRouter matches routes on the URI path alone, and two link forms put the
/// cocktail somewhere else:
/// - `mybartender://cocktail/{id}`: the custom scheme carries `cocktail` as
///   the host, leaving `/{id}` as the path.
/// - `https://share.mybartenderai.com/api/cocktail/{id}`: the share URL the
///   app used up to v1.2.2.
///
/// `https://share.mybartenderai.com/cocktail/{id}` already matches the
/// `/cocktail/:id` route.
library;

const String _shareHost = 'share.mybartenderai.com';

/// Returns the `/cocktail/{id}` location for a link the routes can't match
/// on their own, or null when [uri] needs no redirect.
String? cocktailDeepLinkRedirect(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (uri.scheme == 'mybartender' &&
      uri.host == 'cocktail' &&
      segments.length == 1) {
    return _cocktailLocation(segments[0]);
  }
  if (uri.scheme == 'https' &&
      uri.host == _shareHost &&
      segments.length == 3 &&
      segments[0] == 'api' &&
      segments[1] == 'cocktail') {
    return _cocktailLocation(segments[2]);
  }
  return null;
}

String _cocktailLocation(String id) => '/cocktail/${Uri.encodeComponent(id)}';
