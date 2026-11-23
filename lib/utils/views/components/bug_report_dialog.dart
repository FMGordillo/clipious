import 'dart:io';

import 'package:clipious/globals.dart';
import 'package:clipious/l10n/generated/app_localizations.dart';
import 'package:clipious/settings/states/settings.dart';
import 'package:clipious/utils/bug_report.dart';
import 'package:clipious/utils/models/pending_crash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger('BugReport');

/// Preview of the issue. Nothing is sent until the user opens it in GitHub.
Future<void> showBugReportDialog(
  BuildContext context, {
  required String title,
  String? initialDescription,
  PendingCrash? crash,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BugReportDialog(
      title: title,
      initialDescription: initialDescription,
      crash: crash,
    ),
  );
}

/// Launch prompt: offers the crash saved by the previous run, then forgets it.
Future<void> offerPendingCrashReport(BuildContext context) async {
  final crash = await db.getPendingCrash();
  if (crash == null || !context.mounted) return;
  await showBugReportDialog(
    context,
    title: AppLocalizations.of(context)!.bugReportCrashTitle,
    crash: crash,
  );
  await db.setPendingCrash(null);
}

class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog({
    required this.title,
    this.initialDescription,
    this.crash,
  });

  final String title;
  final String? initialDescription;
  final PendingCrash? crash;

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  late final TextEditingController _description = TextEditingController(
    text: widget.initialDescription,
  );
  bool _openFailed = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context)!.bugReportCopied;
    await Clipboard.setData(ClipboardData(text: text));
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(Uri url) async {
    final navigator = Navigator.of(context);
    try {
      if (await launchUrl(url)) {
        navigator.pop();
        return;
      }
    } catch (err) {
      _log.warning('Could not open GitHub issue', err);
    }
    if (mounted) setState(() => _openFailed = true);
  }

  @override
  Widget build(BuildContext context) {
    final locals = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final packageInfo = context.read<SettingsCubit>().state.packageInfo;
    final crash = widget.crash;
    final description = _description.text;
    final title = buildIssueTitle(
      description: description,
      error: crash?.error,
    );
    final body = buildIssueBody(
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      platform:
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      description: description,
      error: crash?.error,
      stackTrace: crash?.stackTrace,
    );
    final issue = buildIssueUrl(title, body);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(locals.bugReportPublicNote),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: locals.bugReportDescriptionLabel,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: SelectableText(
                  body,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            if (issue.truncated) ...[
              const SizedBox(height: 8),
              Text(locals.bugReportTruncatedNote),
            ],
            if (_openFailed) ...[
              const SizedBox(height: 8),
              Text(
                locals.bugReportOpenFailed,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(locals.cancel),
        ),
        TextButton(
          onPressed: () => _copy('$title\n\n$body'),
          child: Text(locals.copyToClipBoard),
        ),
        FilledButton(
          onPressed: () => _open(issue.url),
          child: Text(locals.bugReportOpenInGitHub),
        ),
      ],
    );
  }
}
