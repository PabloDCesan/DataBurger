//import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

//import '../core/export_service.dart';
//import '../../core/db.dart';
import '../widgets/app_alerts.dart';

///////////////////////////////





typedef ExportAction = Future<void> Function(WidgetRef ref, BuildContext context);
typedef ResetAction  = Future<void> Function(WidgetRef ref, BuildContext context);

List<Widget> buildAdminActions({
  required bool isAdmin,
  required WidgetRef ref,
  required BuildContext context,
  required ExportAction onExport,
  required ResetAction onReset,
  Color? iconColor,
}) {
  if (!isAdmin) return const [];

  return [
    IconButton(
      tooltip: 'Exportar (CSV)',
      icon: const Icon(Icons.download),
      color: iconColor,
      onPressed: () async {
        try {
          await onExport(ref, context);
        } catch (e) {
          showError(context, 'No se pudo exportar: $e');
        }
      },
    ),
    IconButton(
      tooltip: 'Reset DB',
      icon: const Icon(Icons.delete_forever),
      color: iconColor,
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Reiniciar base de datos'),
            content: const Text('Esto eliminará todos los datos locales. ¿Continuar?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reiniciar')),
            ],
          ),
        ) ?? false;

        if (!ok) return;

        try {
          await onReset(ref, context);
          showSuccess(context, 'Base reiniciada');
        } catch (e) {
          showError(context, 'No se pudo reiniciar: $e');
        }
      },
    ),
  ];
}
