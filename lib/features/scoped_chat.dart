import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app_icons.dart';
import '../core/brand.dart';
import '../core/widgets.dart';
import 'community.dart' show LegacyThreadsPage;

String chatRole(String? role) =>
    const {'Teacher': 'مدرس', 'Student': 'طالب', 'Guardian': 'ولي أمر'}[role] ??
    '';
String messageKey() {
  final b = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

class ThreadsPage extends StatefulWidget {
  const ThreadsPage({super.key, required this.api, this.embedded = false});
  final Api api;
  final bool embedded;
  @override
  State<ThreadsPage> createState() => _ThreadsPageState();
}

class _ThreadsPageState extends State<ThreadsPage> {
  String? kind;
  int revision = 0;
  late final studentId = widget.api.guardian
      ? widget.api.portalStudentId
      : null;
  Future<void> start() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StartChatPage(api: widget.api, studentId: studentId),
      ),
    );
    if (mounted) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.api.guardian
                      ? 'تواصل مع مدرسي الابن المختار'
                      : 'محادثاتك وجروبات حصصك',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: start,
                icon: const Icon(AppIcons.add, size: 18),
                label: const Text('بدء محادثة'),
              ),
            ],
          ),
        ),
        if (!widget.api.guardian)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final value in [null, 'Direct', 'SessionGroup'])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(
                        value == null
                            ? 'الكل'
                            : value == 'Direct'
                            ? 'خاص'
                            : 'جروبات الحصص',
                      ),
                      selected: value == kind,
                      onSelected: (_) => setState(() => kind = value),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: PagedList(
            key: ValueKey('$revision-$kind'),
            api: widget.api,
            path: '/chat/conversations',
            query: {
              if (studentId != null) 'studentId': studentId,
              if (kind != null) 'kind': kind,
            },
            item: (c) => BrandCard(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    c['kind'] == 'SessionGroup'
                        ? AppIcons.groupsOutlined
                        : AppIcons.chatBubbleOutline,
                  ),
                ),
                title: Text(
                  '${c['title'] ?? 'محادثة'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c['kind'] == 'SessionGroup')
                      Text(
                        '${c['groupName'] ?? ''} · ${c['status'] == 'Closed' ? 'مغلق' : 'جروب حصة'}',
                      )
                    else if (c['studentName'] != null)
                      Text('بخصوص ${c['studentName']}'),
                    Text(
                      '${c['lastMessage'] ?? 'ابدأ برسالتك الأولى'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: const Icon(AppIcons.chevronLeft),
                onTap: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatConversationPage(
                        api: widget.api,
                        conversation: c,
                      ),
                    ),
                  );
                  if (mounted) setState(() => revision++);
                },
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => open(context, LegacyThreadsPage(api: widget.api)),
          icon: const Icon(AppIcons.history),
          label: const Text('المحادثات السابقة'),
        ),
      ],
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('الرسائل')),
      body: body,
    );
  }
}

class StartChatPage extends StatefulWidget {
  const StartChatPage({super.key, required this.api, this.studentId});
  final Api api;
  final String? studentId;
  @override
  State<StartChatPage> createState() => _StartChatPageState();
}

class _StartChatPageState extends State<StartChatPage> {
  String role = 'Student', search = '';
  String? opening;
  final searchController = TextEditingController();
  Timer? debounce;
  bool get teacher => widget.api.role == 'Teacher';
  late final child =
      widget.studentId ??
      (widget.api.guardian ? widget.api.portalStudentId : widget.api.actorId);
  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> contact(Json c) async {
    if (opening != null) return;
    final key = '${c['role']}-${c['userId']}-${c['studentId']}';
    setState(() => opening = key);
    await action(context, () async {
      final room = obj(
        await widget.api.call(
          'POST',
          '/chat/direct',
          data: {
            'studentId': c['studentId'],
            'teacherId': c['teacherId'],
            if (c['role'] == 'Guardian') 'guardianId': c['userId'],
          },
        ),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatConversationPage(api: widget.api, conversation: room),
        ),
      );
    });
    if (mounted) setState(() => opening = null);
  }

  Future<void> session(Json s) async {
    if (opening != null) return;
    if (s['conversationId'] == null) {
      open(context, SessionChatEditor(api: widget.api, session: s));
      return;
    }
    setState(() => opening = '${s['id']}');
    await action(context, () async {
      final c = obj(
        await widget.api.get('/chat/conversations/${s['conversationId']}'),
      );
      if (mounted) {
        open(context, ChatConversationPage(api: widget.api, conversation: c));
      }
    });
    if (mounted) setState(() => opening = null);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بدء محادثة')),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            teacher
                ? 'اختر طالبًا أو ولي أمر من مجموعاتك، أو افتح جروبًا لحصة.'
                : 'يمكنك التواصل مع المدرسين المرتبطين بتسجيل الطالب في المجموعات النشطة.',
          ),
        ),
        if (teacher)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final value in ['Student', 'Guardian', 'SessionGroup'])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(
                        value == 'SessionGroup'
                            ? 'جروب حصة'
                            : value == 'Student'
                            ? 'الطلاب'
                            : 'أولياء الأمور',
                      ),
                      selected: role == value,
                      onSelected: opening != null
                          ? null
                          : (_) => setState(() => role = value),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: role == 'SessionGroup' && teacher
                  ? 'ابحث باسم المجموعة أو موضوع الحصة'
                  : 'ابحث بالاسم',
              prefixIcon: const Icon(AppIcons.searchRounded),
            ),
            onChanged: (value) {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) setState(() => search = value.trim());
              });
            },
          ),
        ),
        Expanded(
          child: teacher && role == 'SessionGroup'
              ? PagedList(
                  api: widget.api,
                  path: '/chat/session-options',
                  query: {if (search.isNotEmpty) 'search': search},
                  item: (s) => BrandCard(
                    child: ListTile(
                      leading: const Icon(AppIcons.groupsOutlined),
                      title: Text('${s['topic'] ?? s['groupName']}'),
                      subtitle: Text(
                        '${s['groupName']}\n${when(s['startsAtUtc'])}',
                      ),
                      trailing: const Icon(AppIcons.chevronLeft),
                      enabled: opening == null,
                      onTap: () => session(s),
                    ),
                  ),
                )
              : PagedList(
                  api: widget.api,
                  path: '/chat/contacts',
                  query: {
                    if (teacher) 'contactRole': role,
                    if (!teacher && child != null) 'studentId': child,
                    if (search.isNotEmpty) 'search': search,
                  },
                  item: (c) => BrandCard(
                    child: ListTile(
                      enabled: opening == null,
                      leading: CircleAvatar(
                        child: Icon(
                          c['role'] == 'Guardian'
                              ? AppIcons.familyRestroomOutlined
                              : c['role'] == 'Teacher'
                              ? AppIcons.schoolOutlined
                              : AppIcons.personOutline,
                        ),
                      ),
                      title: Text('${c['name'] ?? ''}'),
                      subtitle: Text(
                        c['role'] == 'Guardian'
                            ? 'ولي أمر ${c['studentName']}'
                            : '${chatRole(c['role'])} · ${c['studentName']}',
                      ),
                      trailing:
                          opening ==
                              '${c['role']}-${c['userId']}-${c['studentId']}'
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(AppIcons.chatBubbleOutline),
                      onTap: () => contact(c),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}

class SessionChatEditor extends StatefulWidget {
  const SessionChatEditor({
    super.key,
    required this.api,
    this.session,
    this.conversation,
  });
  final Api api;
  final Json? session, conversation;
  @override
  State<SessionChatEditor> createState() => _SessionChatEditorState();
}

class _SessionChatEditorState extends State<SessionChatEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(
    text:
        '${widget.conversation?['title'] ?? widget.session?['topic'] ?? widget.session?['groupName'] ?? ''}',
  );
  late bool allow = widget.conversation?['allowStudentMessages'] != false;
  late bool closed = widget.conversation?['status'] == 'Closed';
  bool busy = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.conversation == null ? 'جروب الحصة' : 'إعدادات جروب الحصة',
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${widget.conversation?['groupName'] ?? widget.session?['groupName'] ?? ''}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              when(
                widget.conversation?['sessionStartsAtUtc'] ??
                    widget.session?['startsAtUtc'],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'طلاب المجموعة المسجلون حاليًا أعضاء تلقائيًا. لا تحتاج لإضافتهم واحدًا واحدًا، ويتوقف الوصول عند انتهاء تسجيلهم.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: title,
              enabled: !busy,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'اسم الجروب'),
              validator: (v) => (v?.trim().length ?? 0) < 3
                  ? 'اكتب اسمًا من ٣ أحرف على الأقل'
                  : null,
            ),
            SwitchListTile(
              value: allow,
              onChanged: busy ? null : (v) => setState(() => allow = v),
              title: const Text('السماح للطلاب بالرد'),
              subtitle: Text(
                allow
                    ? 'المدرس والطلاب يمكنهم المشاركة'
                    : 'المدرس فقط يرسل الإعلانات',
              ),
            ),
            if (widget.conversation != null)
              SwitchListTile(
                value: closed,
                onChanged: busy ? null : (v) => setState(() => closed = v),
                title: const Text('إغلاق الجروب'),
                subtitle: const Text(
                  'تبقى الرسائل للقراءة ويتوقف الإرسال حتى إعادة فتحه',
                ),
              ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : save,
              icon: const Icon(AppIcons.check),
              label: Text(
                busy
                    ? 'جارٍ الحفظ…'
                    : widget.conversation == null
                    ? 'إنشاء أو فتح جروب الحصة'
                    : 'حفظ الإعدادات',
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final current = widget.conversation;
      final room = obj(
        await widget.api.call(
          current == null ? 'POST' : 'PUT',
          current == null
              ? '/chat/session-groups'
              : '/chat/conversations/${current['id']}/settings',
          data: {
            'title': title.text.trim(),
            'allowStudentMessages': allow,
            if (current == null)
              'sessionId': widget.session!['id']
            else
              'status': closed ? 'Closed' : 'Open',
          },
        ),
      );
      if (!mounted) return;
      if (current == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                ChatConversationPage(api: widget.api, conversation: room),
          ),
        );
      } else {
        Navigator.pop(context, room);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    super.key,
    required this.api,
    required this.conversation,
    this.pollInterval = const Duration(seconds: 5),
  });
  final Api api;
  final Json conversation;
  final Duration pollInterval;
  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage>
    with WidgetsBindingObserver {
  late Json room = Map.of(widget.conversation);
  final input = TextEditingController();
  final scroll = ScrollController();
  final Map<int, Json> messages = {};
  Timer? timer;
  StreamSubscription<String>? subscription;
  int? before;
  bool initial = true,
      latestBusy = false,
      olderBusy = false,
      sending = false,
      denied = false;
  Object? error;
  String? pendingBody, pendingKey;
  String get path => '/chat/conversations/${widget.conversation['id']}';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.api.live.watchThread('${room['id']}');
    subscription = widget.api.live.events
        .where((e) => e == 'ChatChanged' || e == 'Reconnected')
        .listen((_) => load());
    restartTimer();
    load();
  }

  void restartTimer() {
    timer?.cancel();
    if (widget.pollInterval > Duration.zero && !denied) {
      timer = Timer.periodic(widget.pollInterval, (_) => load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      restartTimer();
      load();
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    subscription?.cancel();
    widget.api.live.watchThread(null);
    WidgetsBinding.instance.removeObserver(this);
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void merge(dynamic value) {
    for (final m in rows(value)) {
      final id = (m['id'] as num?)?.toInt();
      if (id != null) messages[id] = m;
    }
  }

  void failure(Object e) {
    if (!mounted) return;
    setState(() {
      error = e;
      if (e is ApiFailure && [401, 403, 404].contains(e.status)) {
        messages.clear();
        room = {};
        denied = true;
        before = null;
        timer?.cancel();
      }
    });
  }

  Future<void> load() async {
    if (latestBusy || denied) return;
    latestBusy = true;
    try {
      final detail = obj(await widget.api.get(path));
      int? after = messages.isEmpty ? null : messages.keys.reduce(max);
      for (var page = 0; page < 5; page++) {
        final batch = obj(
          await widget.api.get('$path/messages', query: {'afterId': ?after}),
        );
        if (!mounted) return;
        setState(() {
          room = detail;
          merge(batch['items']);
          error = null;
          if (initial) before = (batch['nextBeforeId'] as num?)?.toInt();
          initial = false;
        });
        final next = (batch['nextAfterId'] as num?)?.toInt();
        if (next == null || next == after) break;
        after = next;
      }
    } catch (e) {
      failure(e);
    } finally {
      latestBusy = false;
      if (mounted) setState(() => initial = false);
    }
  }

  Future<void> older() async {
    if (olderBusy || before == null || denied) return;
    setState(() => olderBusy = true);
    try {
      final batch = obj(
        await widget.api.get('$path/messages', query: {'beforeId': before}),
      );
      if (!mounted) return;
      setState(() {
        merge(batch['items']);
        before = (batch['nextBeforeId'] as num?)?.toInt();
        error = null;
      });
    } catch (e) {
      failure(e);
    } finally {
      if (mounted) setState(() => olderBusy = false);
    }
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || text.length > 2000 || sending || denied) return;
    if (pendingBody != text) {
      pendingBody = text;
      pendingKey = messageKey();
    }
    setState(() => sending = true);
    try {
      final message = obj(
        await widget.api.call(
          'POST',
          '$path/messages',
          data: {'body': text, 'clientMessageId': pendingKey},
        ),
      );
      if (!mounted) return;
      setState(() {
        merge([message]);
        input.clear();
        pendingBody = null;
        pendingKey = null;
        error = null;
      });
      if (scroll.hasClients) {
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      await load();
    } catch (e) {
      if (e is ApiFailure &&
          ['chat-announcements-only', 'chat-closed'].contains(e.code)) {
        if (mounted) toast(context, e);
        await load();
      } else {
        failure(e);
        if (mounted && !denied) {
          setState(() {
            error =
                'تعذر تأكيد الإرسال. رسالتك محفوظة في خانة الكتابة؛ حاول مرة أخرى.';
          });
        }
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordered = messages.values.toList()
      ..sort((a, b) => (b['id'] as num).compareTo(a['id'] as num));
    final canSend = !initial && !denied && room['canSend'] == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          denied ? 'المحادثة غير متاحة' : '${room['title'] ?? 'المحادثة'}',
        ),
        actions: [
          if (room['canManage'] == true)
            IconButton(
              tooltip: 'إعدادات الجروب',
              icon: const Icon(AppIcons.settingsOutlined),
              onPressed: () async {
                await Navigator.push<Json>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SessionChatEditor(api: widget.api, conversation: room),
                  ),
                );
                if (mounted) await load();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (!denied)
            Container(
              width: double.infinity,
              color: context.brand.primaryTint,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                room['kind'] == 'SessionGroup'
                    ? '${room['groupName'] ?? ''} · ${room['status'] == 'Closed'
                          ? 'الجروب مغلق'
                          : room['allowStudentMessages'] == false
                          ? 'إعلانات المدرس فقط'
                          : 'مشاركة المدرس والطلاب'}'
                    : 'محادثة خاصة${room['studentName'] != null ? ' بخصوص ${room['studentName']}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    denied
                        ? 'لم يعد لديك وصول لهذه المحادثة. راجع تسجيل الطالب في المجموعة أو تواصل مع السنتر.'
                        : '$error',
                  ),
                  if (!denied)
                    TextButton(
                      onPressed: load,
                      child: const Text('إعادة المحاولة'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: initial
                ? const Center(child: CircularProgressIndicator())
                : denied
                ? const SizedBox.shrink()
                : ordered.isEmpty
                ? const Center(child: Empty(text: 'ابدأ برسالتك الأولى'))
                : ListView.builder(
                    controller: scroll,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: ordered.length + (before != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == ordered.length) {
                        return TextButton(
                          onPressed: olderBusy ? null : older,
                          child: Text(
                            olderBusy
                                ? 'جارٍ التحميل…'
                                : 'تحميل الرسائل الأقدم',
                          ),
                        );
                      }
                      final m = ordered[i],
                          own =
                              '${ordered[i]['senderId']}' == widget.api.actorId;
                      return Align(
                        alignment: own
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .82,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: own
                                ? context.brand.primaryTint
                                : context.brand.surface,
                            border: Border.all(color: context.brand.line),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (room['kind'] == 'SessionGroup')
                                Text(
                                  '${m['senderName'] ?? ''} · ${chatRole(m['senderRole'])}',
                                  style: TextStyle(
                                    color: context.brand.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              Text('${m['body'] ?? ''}'),
                              const SizedBox(height: 4),
                              Text(
                                when(m['createdAtUtc']),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (canSend)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        enabled: !sending,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالتك',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'إرسال',
                      onPressed: sending ? null : send,
                      icon: sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(AppIcons.sendRounded),
                    ),
                  ],
                ),
              ),
            )
          else if (!initial && !denied)
            const SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('المحادثة متاحة للقراءة فقط حالياً'),
              ),
            ),
        ],
      ),
    );
  }
}
