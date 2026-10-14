import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/poster.dart';
import '../editor/editor_screen.dart';
import 'project.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.projects;
    return GlassPage(title: 'Loyihalar', slivers: [_body(context, items)]);
  }

  Widget _body(BuildContext context, List<Project> items) {
    final app = AppScope.of(context);
    if (items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: LucideIcons.film,
          title: 'Hali loyiha yo‘q',
          message: 'Suhbatda birinchi videongiz rejasini yarating.',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(childCount: items.length, (
          context,
          i,
        ) {
          final pr = items[i];
          return GestureDetector(
            onLongPress: () => showCupertinoModalPopup<void>(
              context: context,
              builder: (ctx) => CupertinoActionSheet(
                title: Text(pr.name),
                actions: [
                  CupertinoActionSheetAction(
                    isDestructiveAction: true,
                    onPressed: () {
                      app.delete(pr.id);
                      Navigator.pop(ctx);
                    },
                    child: const Text('O‘chirish'),
                  ),
                ],
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Bekor qilish'),
                ),
              ),
            ),
            child: ProjectPosterCard(
              title: pr.name,
              plan: pr.planJson,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => EditorScreen(projectId: pr.id),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
