import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('GitHub Actions Workflow Validation Tests', () {
    final workflowFiles = [
      '.github/workflows/test_main_workflow.yml',
      '.github/workflows/test_firebase_deploy_workflow.yml',
      '.github/workflows/test_gcp_deploy_workflow.yml',
      '.github/workflows/test_release_workflow.yml'
    ];

    setUp(() {
      // Ensure actionlint is installed
      try {
        Process.runSync('which', ['actionlint']);
      } catch (e) {
        fail('actionlint is not installed. Please install it first: '
            'go install github.com/rhysd/actionlint/cmd/actionlint@latest');
      }
    });

    test('All workflow files exist', () {
      for (final file in workflowFiles) {
        expect(File(file).existsSync(), isTrue,
            reason: 'Workflow file $file should exist');
      }
    });

    test('All workflow files have valid syntax', () async {
      for (final file in workflowFiles) {
        final result = await Process.run('actionlint', [file]);
        expect(result.exitCode, equals(0),
            reason: 'Workflow file $file should have valid syntax.\n'
                'Errors: ${result.stderr}');
      }
    });

    test('Required secrets are properly referenced', () async {
      final requiredSecrets = [
        'FIREBASE_TOKEN',
        'GCP_PROJECT_ID',
        'GCP_SA_KEY',
        'GITHUB_TOKEN'
      ];

      for (final file in workflowFiles) {
        final content = await File(file).readAsString();
        
        for (final secret in requiredSecrets) {
          if (content.contains('secrets.$secret')) {
            final result = await Process.run('actionlint', ['-no-color', file]);
            expect(result.stderr.contains('secrets.$secret'), isFalse,
                reason: 'Secret $secret in $file should be properly referenced');
          }
        }
      }
    });

    test('Job dependencies are valid', () async {
      for (final file in workflowFiles) {
        final result = await Process.run(
            'actionlint', ['-no-color', '-format', '{{json .}}', file]);
        expect(result.exitCode, equals(0),
            reason: 'Job dependencies in $file should be valid.\n'
                'Errors: ${result.stderr}');
      }
    });

    test('Workflow triggers are properly configured', () async {
      for (final file in workflowFiles) {
        final result = await Process.run('actionlint', ['-no-color', file]);
        expect(result.stderr.contains('workflow trigger'), isFalse,
            reason: 'Workflow triggers in $file should be valid');
      }
    });

    test('Environment configurations are valid', () async {
      for (final file in workflowFiles) {
        final content = await File(file).readAsString();
        
        if (content.contains('environment:')) {
          final result = await Process.run('actionlint', ['-no-color', file]);
          expect(result.stderr.contains('environment'), isFalse,
              reason: 'Environment configurations in $file should be valid');
        }
      }
    });
  });
}