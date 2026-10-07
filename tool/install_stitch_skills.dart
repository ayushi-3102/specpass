import 'dart:io';

void main() async {
  final repoDir = Directory(r'C:\Users\ayush\.gemini\config\skills\temp_stitch_skills');
  final targetBaseDir = Directory(r'C:\Users\ayush\.gemini\config\skills');

  if (!repoDir.existsSync()) {
    print('Repository temp_stitch_skills does not exist!');
    return;
  }

  final pluginsDir = Directory('${repoDir.path}\\plugins');
  int installedCount = 0;

  for (final pluginDir in pluginsDir.listSync().whereType<Directory>()) {
    final skillsDir = Directory('${pluginDir.path}\\skills');
    if (!skillsDir.existsSync()) continue;

    for (final skillDir in skillsDir.listSync().whereType<Directory>()) {
      final skillName = skillDir.uri.pathSegments[skillDir.uri.pathSegments.length - 2];
      final targetSkillName = skillName.startsWith('stitch') ? skillName : 'stitch-$skillName';
      final targetSkillDir = Directory('${targetBaseDir.path}\\$targetSkillName');

      if (!targetSkillDir.existsSync()) {
        targetSkillDir.createSync(recursive: true);
      }

      print('Installing skill: $skillName -> $targetSkillName');

      // Copy all contents recursively
      copyDirectorySync(skillDir, targetSkillDir);

      // Clean up SKILL.md frontmatter name to match folder name
      final skillMdFile = File('${targetSkillDir.path}\\SKILL.md');
      if (skillMdFile.existsSync()) {
        String content = skillMdFile.readAsStringSync();
        // Replace name: stitch::xyz or name: xyz with name: targetSkillName
        content = content.replaceFirst(
          RegExp(r'^name:\s*.*$', multiLine: true),
          'name: $targetSkillName',
        );
        skillMdFile.writeAsStringSync(content);
      }

      installedCount++;
    }
  }

  print('\nSuccessfully installed $installedCount Stitch skills into ${targetBaseDir.path}!');
}

void copyDirectorySync(Directory source, Directory destination) {
  for (var entity in source.listSync(recursive: false)) {
    final newPath = '${destination.path}\\${entity.uri.pathSegments.last.isNotEmpty ? entity.uri.pathSegments.last : entity.uri.pathSegments[entity.uri.pathSegments.length - 2]}';
    if (entity is Directory) {
      final newDir = Directory(newPath);
      if (!newDir.existsSync()) newDir.createSync(recursive: true);
      copyDirectorySync(entity, newDir);
    } else if (entity is File) {
      entity.copySync(newPath);
    }
  }
}
