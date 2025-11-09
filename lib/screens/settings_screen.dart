import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'AI Configuration',
              subtitle: 'Manage API keys for AI-powered processing',
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.key_outlined,
                    title: 'API Keys',
                    subtitle: 'Configure OpenAI, Gemini, Anthropic & Groq',
                    onTap: () => _showApiKeysSheet(context),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _SectionTitle(
              title: 'Voice Recording',
              subtitle: 'Configure speech-to-text settings',
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              child: Consumer<PortaThoughtyState>(
                builder: (context, state, _) {
                  final silenceTimeout = state.settings.silenceTimeout;
                  return Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.timer_outlined,
                        title: 'Silence Timeout',
                        subtitle: '${silenceTimeout.inSeconds}s - Auto-stop after silence',
                        onTap: () => _showSilenceTimeoutDialog(context, state),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            _SectionTitle(
              title: 'App Behavior',
              subtitle: 'Customize how the app works',
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              child: Consumer<PortaThoughtyState>(
                builder: (context, state, _) {
                  final pipEnabled = state.settings.pipEnabled;
                  return Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.picture_in_picture_outlined,
                        title: 'Picture-in-Picture',
                        subtitle: pipEnabled
                            ? 'Enabled - App appears as floating button when minimized'
                            : 'Disabled - Normal minimize behavior',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          state.updatePipEnabled(!pipEnabled);
                        },
                        trailing: Switch(
                          value: pipEnabled,
                          onChanged: (value) {
                            HapticFeedback.lightImpact();
                            state.updatePipEnabled(value);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            _SectionTitle(
              title: 'About',
              subtitle: 'App information',
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: 'Version',
                    subtitle: '1.0.0',
                    onTap: null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showApiKeysSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ApiKeysSheet(),
    );
  }

  Future<void> _showSilenceTimeoutDialog(
    BuildContext context,
    PortaThoughtyState state,
  ) async {
    final controller = TextEditingController(
      text: state.settings.silenceTimeout.inSeconds.toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silence Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Seconds of silence before auto-stopping recording'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Seconds',
                border: OutlineInputBorder(),
                suffixText: 's',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final seconds = int.tryParse(controller.text);
              if (seconds != null && seconds > 0) {
                Navigator.pop(context, seconds);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await state.updateSilenceTimeout(Duration(seconds: result));
    }
  }
}

class _ApiKeysSheet extends StatefulWidget {
  const _ApiKeysSheet();

  @override
  State<_ApiKeysSheet> createState() => _ApiKeysSheetState();
}

class _ApiKeysSheetState extends State<_ApiKeysSheet> {
  final _openaiController = TextEditingController();
  final _geminiController = TextEditingController();
  final _anthropicController = TextEditingController();
  final _groqController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }

  @override
  void dispose() {
    _openaiController.dispose();
    _geminiController.dispose();
    _anthropicController.dispose();
    _groqController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKeys() async {
    final state = context.read<PortaThoughtyState>();
    setState(() {
      _openaiController.text = state.settings.openaiApiKey ?? '';
      _geminiController.text = state.settings.geminiApiKey ?? '';
      _anthropicController.text = state.settings.anthropicApiKey ?? '';
      _groqController.text = state.settings.groqApiKey ?? '';
    });
  }

  Future<void> _pasteFromClipboard(TextEditingController controller) async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        controller.text = data!.text!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasted from clipboard'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _saveApiKeys() async {
    HapticFeedback.mediumImpact();
    final state = context.read<PortaThoughtyState>();

    await state.updateApiKeys(
      openai: _openaiController.text.trim().isEmpty ? null : _openaiController.text.trim(),
      gemini: _geminiController.text.trim().isEmpty ? null : _geminiController.text.trim(),
      anthropic: _anthropicController.text.trim().isEmpty ? null : _anthropicController.text.trim(),
      groq: _groqController.text.trim().isEmpty ? null : _groqController.text.trim(),
    );

    if (mounted) {
      HapticFeedback.lightImpact();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API keys saved securely'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 32,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.key_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'API Keys',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Configure your AI provider API keys. Keys are stored securely on your device.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _ApiKeyField(
                  controller: _openaiController,
                  label: 'OpenAI API Key',
                  hint: 'sk-...',
                  icon: Icons.smart_toy_outlined,
                  onPaste: () => _pasteFromClipboard(_openaiController),
                ),
                const SizedBox(height: 16),
                _ApiKeyField(
                  controller: _geminiController,
                  label: 'Google Gemini API Key',
                  hint: 'AIza...',
                  icon: Icons.psychology_outlined,
                  onPaste: () => _pasteFromClipboard(_geminiController),
                ),
                const SizedBox(height: 16),
                _ApiKeyField(
                  controller: _anthropicController,
                  label: 'Anthropic API Key',
                  hint: 'sk-ant-...',
                  icon: Icons.analytics_outlined,
                  onPaste: () => _pasteFromClipboard(_anthropicController),
                ),
                const SizedBox(height: 16),
                _ApiKeyField(
                  controller: _groqController,
                  label: 'Groq API Key',
                  hint: 'gsk_...',
                  icon: Icons.flash_on_outlined,
                  onPaste: () => _pasteFromClipboard(_groqController),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saveApiKeys,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Save Keys'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApiKeyField extends StatefulWidget {
  const _ApiKeyField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onPaste,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback onPaste;

  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        prefixIcon: Icon(widget.icon),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
              tooltip: _obscureText ? 'Show key' : 'Hide key',
              onPressed: () {
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.content_paste),
              tooltip: 'Paste from clipboard',
              onPressed: widget.onPaste,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12014F8E),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: title,
      hint: subtitle,
      button: onTap != null,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap != null ? () {
          HapticFeedback.lightImpact();
          onTap!();
        } : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
