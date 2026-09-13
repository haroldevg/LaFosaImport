{{flutter_js}}
{{flutter_build_config}}

// No serviceWorkerSettings on purpose: this app is always used online, and
// Flutter's default service worker caching was serving stale builds to
// returning visitors after every deploy (see Firebase Hosting cache-control
// headers in firebase.json for the same fix on the HTTP layer).
_flutter.loader.load();
