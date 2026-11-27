import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/legal_documents.dart';

class LegalPolicyScreen extends StatelessWidget {
  final LegalPolicyType type;

  const LegalPolicyScreen({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isPrivacyPolicy = type == LegalPolicyType.privacyPolicy;
    final theme = Theme.of(context);
    final title = isPrivacyPolicy ? 'Privacy Policy' : 'Terms & Conditions';
    final sections = legalPolicySections(type);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SelectionArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Egg Farm Manager',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'eggfarmmanager.in',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('Support: eggfarmsupport@gmail.com'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final section in sections)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.$1,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            section.$2,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(
                      isPrivacyPolicy ? '/terms' : '/privacy-policy',
                    ),
                    child: Text(
                      isPrivacyPolicy
                          ? 'Read Terms & Conditions'
                          : 'Read Privacy Policy',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
