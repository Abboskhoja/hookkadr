import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    return Scaffold(
      // Lists run under the floating glass tab bar; their own bottom
      // padding keeps the last row reachable above it.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader('Loyihalar'),
            Expanded(child: _body(context, items)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<Project> items) {
    final app = AppScope.of(context);
    return items.isEmpty
        ? const EmptyState(
            icon: LucideIcons.film,
            title: 'Hali loyiha yo‘q',
            message: 'Suhbatda birinchi videongiz rejasini yarating.',
          )
        : GridView.builder(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
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
            },
          );
  }
}
