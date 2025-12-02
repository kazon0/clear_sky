import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/api_config.dart';

class AiChatViewModel extends ChangeNotifier {
  bool isLoading = false;
  bool isAiTyping = false;

  bool isHumanConsult = false; // 已被接管
  bool isWaiting = false; // 正在等待接管
  bool isCompleted = false; // 对话已结束
  bool _isPollingStarted = false; // 防重复启动消息轮询

  Timer? statusTimer; // 定时器（每秒检查一次是否被接管）
  Timer? messageTimer;
  String currentTitle = 'AI 心理陪伴';
  String? _lastUserMessage;

  int? conversationId;
  List<Map<String, dynamic>> messages = [];
  List<dynamic> conversations = [];

  /// 初始化
  Future<void> initChat() async {
    isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getInt('lastConversationId');

    if (lastId != null) {
      await loadConversationDetail(lastId);
    } else {
      await createConversation('新的对话');
    }

    await loadConversationList();
    isLoading = false;
    notifyListeners();
  }

  /// 创建新会话
  Future<void> createConversation(String title) async {
    final res = await AiService.createConversation(title);
    if (res['code'] == 200) {
      conversationId = res['data']['conversationId'];
      currentTitle = title;

      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('lastConversationId', conversationId!);

      messages.clear();
      _resetStatus();
      notifyListeners();
    }
  }

  /// 重置状态
  void _resetStatus() {
    isHumanConsult = false;
    isWaiting = false;
    isCompleted = false;
    _isPollingStarted = false; // ❗必须重置（避免切换会话时残留）
    statusTimer?.cancel();
    messageTimer?.cancel();
  }

  /// 加载会话详情
  Future<void> loadConversationDetail(int id) async {
    isLoading = true;
    notifyListeners();

    try {
      final res = await AiService.getConversationDetail(id);
      if (res['code'] == 200) {
        final data = res['data'];
        conversationId = data['id'];
        currentTitle = data['title'] ?? 'AI 心理陪伴';

        _applyStatus(data); // 状态必须先更新

        // 历史消息
        final list = data['messages'] as List<dynamic>;
        messages = list
            .map(
              (m) => {
                'text': m['content'],
                'isUser': m['senderType'] == 'USER',
              },
            )
            .toList();

        final prefs = await SharedPreferences.getInstance();
        prefs.setInt('lastConversationId', id);
      }
    } catch (_) {}

    isLoading = false;
    notifyListeners();
  }

  /// 应用状态
  void _applyStatus(Map<String, dynamic> data) {
    // --- 1. 防止 AI 回复把 status 覆盖掉 ---
    final status = data.containsKey('status') ? data['status'] : null;
    final risk = data.containsKey('riskLevel') ? data['riskLevel'] : null;

    // --- 2. completed 一旦 true 就永远 true ---
    if (status == 'COMPLETED') {
      isCompleted = true;
    }

    // --- 3. 接管状态锁死，只允许从 false→true，不能从 true→false ---
    if (status == 'ESCALATED') {
      isHumanConsult = true;
    }

    // --- 4. 是否等待接管的逻辑也不能被 AI 回复覆盖 ---
    if (!isHumanConsult && !isCompleted && risk == 'CRITICAL') {
      isWaiting = true;
      _startWaitingMonitor();
    } else if (status != null) {
      // 只有后台明确返回状态时，才允许前端改变等待状态
      isWaiting = false;
    }

    // --- 5. 启动人工消息轮询（只执行一次） ---
    if (isHumanConsult && !_isPollingStarted) {
      _isPollingStarted = true;
      statusTimer?.cancel();
      _startMessagePolling();
    }
  }

  /// 启动 1秒定时器检查是否已经被接管
  void _startWaitingMonitor() {
    statusTimer?.cancel();
    statusTimer = Timer.periodic(Duration(seconds: 1), (_) async {
      if (conversationId == null) return;
      final res = await AiService.getConversationDetail(conversationId!);
      if (res['code'] == 200) {
        final status = res['data']['status'];

        // 被接管！
        if (status == 'ESCALATED') {
          isHumanConsult = true;
          isWaiting = false;
          messages.add({'text': '⚠ 咨询师已接管对话。', 'isUser': false});
          statusTimer?.cancel();
          notifyListeners();
        }

        // 已结束
        if (status == 'COMPLETED') {
          isCompleted = true;
          isWaiting = false;
          statusTimer?.cancel();
          notifyListeners();
        }
      }
    });
  }

  /// 人工接管后轮询新消息
  void _startMessagePolling() {
    messageTimer?.cancel();

    if (!isHumanConsult) return;

    messageTimer = Timer.periodic(Duration(seconds: 2), (_) async {
      if (conversationId == null) return;

      final res = await AiService.getConversationDetail(conversationId!);
      if (res['code'] == 200) {
        final data = res['data'];

        _applyStatus(data); // 轮询时也要同步状态，保证横幅不消失

        final list = data['messages'] as List<dynamic>;
        final newMessages = list
            .map(
              (m) => {
                'text': m['content'],
                'isUser': m['senderType'] == 'USER',
              },
            )
            .toList();

        // 差量更新消息
        // 差量更新消息（带顺序矫正 + 去重）
        if (newMessages.length > messages.length) {
          final diff = newMessages.sublist(messages.length);

          for (var m in diff) {
            final text = m['text'];
            final isUser = m['isUser'] == true;

            // ① 去重：用户刚发过的消息，跳过
            if (isUser && text == _lastUserMessage) {
              continue;
            }

            // ② 顺序矫正：如果本地已经有该用户消息，则管理员消息补前面
            if (isUser) {
              // 本地是否已包含此内容
              final alreadyExists = messages.any(
                (x) => x['text'] == text && x['isUser'] == true,
              );
              if (alreadyExists) {
                continue; // 用户消息已存在，不补重复
              }
            }

            messages.add(m);
          }
        }

        notifyListeners();
      }
    });
  }

  /// 发送消息
  Future<void> sendMessage(String content) async {
    if (conversationId == null || content.trim().isEmpty) return;

    // 会话已结束 → 禁止发送
    if (isCompleted) {
      messages.add({'text': '本次咨询已结束，无法继续发送消息。', 'isUser': false});
      notifyListeners();
      return;
    }

    // 用户消息立即显示（必须刷新，否则用户看不到）
    messages.add({'text': content, 'isUser': true});
    notifyListeners();

    // 设置 AI 输入状态（但不立即刷新，避免横幅闪）
    isAiTyping = true;

    try {
      Map<String, dynamic> res;

      if (isHumanConsult) {
        res = await AiService.sendHumanMessage(conversationId!, content);
      } else {
        res = await AiService.sendMessage(conversationId!, content);
      }

      // 如果 data 为空，代表等待接管
      if (res['data'] == null) {
        isAiTyping = false;
        messages.add({'text': '正在等待接管...', 'isUser': false});
        notifyListeners();
        return;
      }

      final data = res['data'];

      // 更新状态（避免横幅闪烁，必须放在 reply 之前）
      _applyStatus(data);

      final reply = data['content'];
      final senderType = data['senderType'];

      if (reply != null &&
          reply.toString().trim().isNotEmpty &&
          senderType != 'USER') {
        messages.add({'text': reply, 'isUser': false});
      }
    } catch (e) {
      messages.add({'text': '网络异常：$e', 'isUser': false});
    } finally {
      isAiTyping = false;
      notifyListeners();
    }
  }

  /// 会话列表
  Future<void> loadConversationList() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final url = Uri.parse('$baseUrl/ai/conversations');
      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.body.isNotEmpty) {
        final data = json.decode(res.body);
        conversations = data['data']['list'] ?? [];
      }
    } catch (_) {
      conversations = [];
    }

    notifyListeners();
  }

  /// 切换会话
  Future<void> switchConversation(int id) async {
    await loadConversationDetail(id);
  }

  void clear() {
    messages.clear();
    conversationId = null;

    _resetStatus(); // 重置所有状态（包括 _isPollingStarted）

    notifyListeners();
  }
}
