import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  
  // 1. Check latest workflow run
  final runReq = await client.getUrl(Uri.parse('https://api.github.com/repos/ayushi-3102/specpass/actions/runs?per_page=1'));
  runReq.headers.set('User-Agent', 'Dart');
  final runRes = await runReq.close();
  final runBody = await runRes.transform(utf8.decoder).join();
  final runJson = jsonDecode(runBody) as Map<String, dynamic>;
  final runs = runJson['workflow_runs'] as List<dynamic>;
  if (runs.isNotEmpty) {
    final latest = runs[0] as Map<String, dynamic>;
    print('Latest Run ID: ${latest['id']}');
    print('Status: ${latest['status']}');
    print('Conclusion: ${latest['conclusion']}');
    print('Commit: ${latest['head_commit']?['message']}');
    print('URL: ${latest['html_url']}');
  }

  // 2. Check latest release assets
  final relReq = await client.getUrl(Uri.parse('https://api.github.com/repos/ayushi-3102/specpass/releases'));
  relReq.headers.set('User-Agent', 'Dart');
  final relRes = await relReq.close();
  final relBody = await relRes.transform(utf8.decoder).join();
  final relJson = jsonDecode(relBody) as List<dynamic>;
  if (relJson.isNotEmpty) {
    final latestRel = relJson[0] as Map<String, dynamic>;
    print('\nLatest Release Tag: ${latestRel['tag_name']}');
    final assets = latestRel['assets'] as List<dynamic>;
    for (final a in assets) {
      print('Asset: ${a['name']} (${(a['size'] / 1024 / 1024).toStringAsFixed(1)} MB) - Updated: ${a['updated_at']}');
      print('Download URL: ${a['browser_download_url']}');
    }
  }

  client.close();
}
