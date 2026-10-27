import 'dart:async';
import 'dart:convert';
import 'package:signalr_netcore/signalr_client.dart';
import 'api.dart';

/// One foreground connection per authenticated app. REST is authoritative.
class LiveUpdates {
  LiveUpdates(this.api);
  final Api api;
  final _events = StreamController<String>.broadcast();
  Stream<String> get events => _events.stream;
  HubConnection? _hub;
  String? _session, _thread;
  Timer? _retry, _debounce;
  final Set<String> pendingEvents = {};
  int attempts = 0;
  bool running = false, starting = false;
  void emit(String event) {
    pendingEvents.add(event);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      for (final name in pendingEvents.toList()) {
        _events.add(name);
      }
      pendingEvents.clear();
    });
  }

  Future<void> start() async {
    running = true;
    if (starting ||
        !api.signedIn ||
        _hub?.state == HubConnectionState.Connected) {
      return;
    }
    starting = true;
    try {
      final hub = _hub ??= HubConnectionBuilder()
          .withUrl(
            api.resolveUrl('/hubs/center').toString(),
            options: HttpConnectionOptions(
              transport: HttpTransportType.WebSockets,
              requestTimeout: 15000,
              accessTokenFactory: () async {
                if (!api.signedIn) return '';
                try {
                  final payload = obj(
                    jsonDecode(
                      utf8.decode(
                        base64Url.decode(
                          base64Url.normalize(api.token.split('.')[1]),
                        ),
                      ),
                    ),
                  );
                  final exp = payload['exp'];
                  if (exp is num &&
                      exp * 1000 <
                          DateTime.now().millisecondsSinceEpoch + 60000) {
                    await api.refresh();
                  }
                } on FormatException {
                  await api.refresh();
                }
                return api.token;
              },
            ),
          )
          .withAutomaticReconnect(retryDelays: [0, 2000, 10000, 30000])
          .build();
      hub.off('NotificationsChanged');
      hub.off('ThreadChanged');
      hub.off('AttendanceChanged');
      hub.off('CheckInChanged');
      for (final event in [
        'NotificationsChanged',
        'ThreadChanged',
        'AttendanceChanged',
        'CheckInChanged',
      ]) {
        hub.on(event, (_) => emit(event));
      }
      hub.onreconnected(({connectionId}) {
        _restoreWatches();
        emit('Reconnected');
      });
      hub.onclose(({error}) {
        if (running) _schedule();
      });
      await hub.start();
      if (!running) {
        await hub.stop();
        return;
      }
      attempts = 0;
      await _restoreWatches();
      emit('Reconnected');
    } catch (_) {
      if (running) _schedule();
    } finally {
      starting = false;
    }
  }

  void _schedule() {
    if (attempts >= 5) return;
    _retry?.cancel();
    final seconds = [2, 5, 10, 20, 30][attempts++];
    _retry = Timer(Duration(seconds: seconds), start);
  }

  Future<void> _restoreWatches() async {
    try {
      if (_session != null) {
        await _hub?.invoke('WatchSession', args: [_session!]);
      }
      if (_thread != null) await _hub?.invoke('WatchThread', args: [_thread!]);
    } catch (_) {}
  }

  Future<void> watchSession(String? id) async {
    _session = id;
    try {
      if (_hub?.state == HubConnectionState.Connected) {
        await _hub?.invoke(
          id == null ? 'UnwatchSession' : 'WatchSession',
          args: id == null ? [] : [id],
        );
      }
    } catch (_) {}
  }

  Future<void> watchThread(String? id) async {
    _thread = id;
    try {
      if (_hub?.state == HubConnectionState.Connected) {
        await _hub?.invoke(
          id == null ? 'UnwatchThread' : 'WatchThread',
          args: id == null ? [] : [id],
        );
      }
    } catch (_) {}
  }

  Future<void> stop({bool clear = false}) async {
    running = false;
    attempts = 0;
    _retry?.cancel();
    _debounce?.cancel();
    if (clear) {
      _session = null;
      _thread = null;
    }
    final hub = _hub;
    _hub = null;
    await hub?.stop();
  }
}
