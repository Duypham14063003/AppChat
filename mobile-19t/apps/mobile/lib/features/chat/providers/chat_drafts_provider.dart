import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatDraftsNotifier extends Notifier<Map<String, String>> {
  static const _storageKey = 'chat_draft_messages';
  bool _loaded = false;

  @override
  Map<String, String> build() {
    if (!_loaded) {
      _loaded = true;
      Future<void>.microtask(_loadSavedDrafts);
    }
    return const {};
  }

  Future<void> _loadSavedDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_storageKey);
      if (savedStr != null && savedStr.isNotEmpty) {
        final decoded = json.decode(savedStr) as Map<String, dynamic>;
        final draftsMap = decoded.map((key, value) => MapEntry(key, value.toString()));
        state = draftsMap;
      }
    } catch (e) {
      debugPrint('[Drafts] Load saved drafts error: $e');
    }
  }

  Future<void> setDraft(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      if (!state.containsKey(conversationId)) return;
      final newState = Map<String, String>.from(state);
      newState.remove(conversationId);
      state = newState;
    } else {
      if (state[conversationId] == text) return;
      state = {
        ...state,
        conversationId: text,
      };
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (state.isEmpty) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, json.encode(state));
      }
    } catch (e) {
      debugPrint('[Drafts] Save draft error: $e');
    }
  }
}

final chatDraftsProvider = NotifierProvider<ChatDraftsNotifier, Map<String, String>>(
  ChatDraftsNotifier.new,
);
