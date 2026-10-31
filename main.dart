import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const NewsApp());
}

class NewsApp extends StatelessWidget {
  const NewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Daily Headlines',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const NewsHomePage(),
    );
  }
}

class Story {
  final int id;
  final String title;
  final String author;
  final String url;
  final String text;
  final int score;
  final int comments;
  final int time;

  const Story({
    required this.id,
    required this.title,
    required this.author,
    required this.url,
    required this.text,
    required this.score,
    required this.comments,
    required this.time,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int? ?? 0;

    return Story(
      id: id,
      title: json['title'] as String? ?? 'Untitled story',
      author: json['by'] as String? ?? 'Unknown',
      url: json['url'] as String? ?? 'https://news.ycombinator.com/item?id=$id',
      text: json['text'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      comments: json['descendants'] as int? ?? 0,
      time: json['time'] as int? ?? 0,
    );
  }
}

class NewsHomePage extends StatefulWidget {
  const NewsHomePage({super.key});

  @override
  State<NewsHomePage> createState() => _NewsHomePageState();
}

class _NewsHomePageState extends State<NewsHomePage> {
  static const String api = 'https://hacker-news.firebaseio.com/v0';

  List<Story> stories = [];
  bool isLoading = false;
  String errorMessage = '';

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchNews();
  }

  Future<void> fetchNews() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http
          .get(Uri.parse('$api/topstories.json'))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch headlines.');
      }

      final List<dynamic> ids = jsonDecode(response.body);

      if (ids.isEmpty) {
        throw Exception('No headlines available.');
      }

      final results = await Future.wait(
        ids.take(30).map((id) async {
          final res = await http
              .get(Uri.parse('$api/item/$id.json'))
              .timeout(const Duration(seconds: 15));

          if (res.statusCode != 200) {
            return null;
          }

          final dynamic data = jsonDecode(res.body);

          if (data is! Map<String, dynamic> ||
              data['title'] == null ||
              data['deleted'] == true ||
              data['dead'] == true) {
            return null;
          }

          return Story.fromJson(data);
        }),
      );

      final loadedStories = results.whereType<Story>().toList();

      if (loadedStories.isEmpty) {
        throw Exception('No headlines could be loaded.');
      }

      if (!mounted) return;

      setState(() {
        stories = loadedStories;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load news. Check your internet connection '
            'and try again.';
      });
    }
  }

  List<Story> get filteredStories {
    final query = searchController.text.toLowerCase().trim();

    return stories.where((story) {
      return story.title.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daily Headlines',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: isLoading ? null : fetchNews,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh news',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search headlines...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(child: buildContent()),
        ],
      ),
    );
  }

  Widget buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading news headlines...'),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 50,
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: fetchNews,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = filteredStories;

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No matching headlines found.'),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchNews,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final story = filtered[index];

          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                child: Text('${index + 1}'),
              ),
              title: Text(
                story.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Author: ${story.author}\n'
                  'Points: ${story.score} | '
                  'Comments: ${story.comments}',
                ),
              ),
              isThreeLine: true,
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 18,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewsDetailsPage(story: story),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class NewsDetailsPage extends StatelessWidget {
  final Story story;

  const NewsDetailsPage({
    super.key,
    required this.story,
  });

  Future<void> openArticle(BuildContext context) async {
    final uri = Uri.tryParse(story.url);

    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid article URL.'),
        ),
      );
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open the article link.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening the article link.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final published = story.time == 0
        ? 'Unknown'
        : DateTime.fromMillisecondsSinceEpoch(
            story.time * 1000,
          ).toLocal().toString().substring(0, 16);

    final cleanText = story.text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&#x27;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&');

    return Scaffold(
      appBar: AppBar(
        title: const Text('News Details'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.newspaper,
            size: 55,
            color: Colors.indigo,
          ),
          const SizedBox(height: 20),
          Text(
            story.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text('Author: ${story.author}'),
          const SizedBox(height: 8),
          Text('Published: $published'),
          const SizedBox(height: 8),
          Text('Points: ${story.score}'),
          const SizedBox(height: 8),
          Text('Comments: ${story.comments}'),
          const Divider(height: 32),
          const Text(
            'Story content',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            cleanText.isNotEmpty
                ? cleanText
                : 'The API does not provide the full article text '
                    'for this story. Tap the URL below to read it.',
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Original article URL',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => openArticle(context),
            child: Text(
              story.url,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => openArticle(context),
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Read Full Article'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hacker News discussion',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SelectableText(
            'https://news.ycombinator.com/item?id=${story.id}',
            style: const TextStyle(color: Colors.indigo),
          ),
        ],
      ),
    );
  }
}
