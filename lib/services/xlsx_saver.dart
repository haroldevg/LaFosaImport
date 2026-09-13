/// Hands a generated .xlsx to the platform: the OS share sheet on
/// Android/iOS, a plain browser download on web.
///
/// The two live in separate files because their dependencies don't exist on
/// the other platform — path_provider and share_plus have no web
/// implementation (calling them from a web build throws
/// MissingPluginException), and `package:web` can't be compiled into a mobile
/// build. The conditional export picks one at compile time, exactly like
/// google_sign_in_web_button.dart does.
export 'xlsx_saver_io.dart' if (dart.library.js_util) 'xlsx_saver_web.dart';
