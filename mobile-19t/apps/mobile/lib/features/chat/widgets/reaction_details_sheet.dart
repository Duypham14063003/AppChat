import 'package:flutter/material.dart';

import '../../../core/theme/theme_color_presets.dart';
import '../models/reaction_group.dart';

void showReactionDetailsSheet(
  BuildContext context,
  List<ReactionGroup> reactions,
) {
  final palette = context.appPalette;
  final isWide = MediaQuery.of(context).size.width >= 768;

  if (isWide) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 480,
          height: 450,
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(bottom: BorderSide(color: palette.surfaceVariant)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Cảm xúc về tin nhắn',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: palette.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReactionDetailsSheet(
                  reactions: reactions,
                  asDialog: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ReactionDetailsSheet(reactions: reactions),
    );
  }
}

class ReactionDetailsSheet extends StatefulWidget {
  final List<ReactionGroup> reactions;
  final bool asDialog;

  const ReactionDetailsSheet({
    super.key,
    required this.reactions,
    this.asDialog = false,
  });

  @override
  State<ReactionDetailsSheet> createState() => _ReactionDetailsSheetState();
}

class _ReactionDetailsSheetState extends State<ReactionDetailsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int get _totalCount => widget.reactions.fold(0, (sum, g) => sum + g.count);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.reactions.length + 1, // "All" + per-emoji
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    if (widget.asDialog) {
      return Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: palette.primary,
            unselectedLabelColor: palette.textSecondary,
            indicatorColor: palette.primary,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Tất cả $_totalCount'),
              ...widget.reactions.map(
                (g) => Tab(text: '${g.emoji} ${g.count}'),
              ),
            ],
          ),
          Divider(height: 1, color: palette.surfaceVariant),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(
                  null,
                  widget.reactions
                      .expand(
                        (g) => g.users.map((u) => _UserEmoji(u, g.emoji)),
                      )
                      .toList(),
                ),
                ...widget.reactions.map(
                  (g) => _buildUserList(
                    null,
                    g.users.map((u) => _UserEmoji(u, g.emoji)).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: palette.surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: palette.primary,
                unselectedLabelColor: palette.textSecondary,
                indicatorColor: palette.primary,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Tất cả $_totalCount'),
                  ...widget.reactions.map(
                    (g) => Tab(text: '${g.emoji} ${g.count}'),
                  ),
                ],
              ),
              Divider(height: 1, color: palette.surfaceVariant),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUserList(
                      scrollController,
                      widget.reactions
                          .expand(
                            (g) => g.users.map((u) => _UserEmoji(u, g.emoji)),
                          )
                          .toList(),
                    ),
                    ...widget.reactions.map(
                      (g) => _buildUserList(
                        scrollController,
                        g.users.map((u) => _UserEmoji(u, g.emoji)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserList(ScrollController? controller, List<_UserEmoji> items) {
    final palette = context.appPalette;

    return ListView.builder(
      controller: controller,
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          textColor: palette.textPrimary,
          iconColor: palette.textSecondary,
          dense: true,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: palette.surfaceVariant,
            child: Text(
              item.user.name.isNotEmpty ? item.user.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: palette.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(
            item.user.name,
            style: TextStyle(
              fontSize: 14,
              color: palette.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Text(item.emoji, style: const TextStyle(fontSize: 20)),
        );
      },
    );
  }
}

class _UserEmoji {
  final ReactionUser user;
  final String emoji;
  _UserEmoji(this.user, this.emoji);
}
