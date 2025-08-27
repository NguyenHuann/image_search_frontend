import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const ImageSearchApp());

// Đổi qua URL VPS/Render khi deploy:
// - Emulator Android: http://10.0.2.2:5000
// - Thiết bị thật:    http://<IP LAN PC>:5000
const String baseUrl = 'http://10.0.2.2:5000';

class ImageSearchApp extends StatelessWidget {
  const ImageSearchApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Image Search',
      home: ImageSearchPage(),
    );
  }
}

class ImageSearchPage extends StatefulWidget {
  const ImageSearchPage({super.key});
  @override
  State<ImageSearchPage> createState() => _ImageSearchPageState();
}

class _ImageSearchPageState extends State<ImageSearchPage> {
  File? _image;
  dynamic _results; // có thể là List hoặc String (lỗi)

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> sendImageToAPI() async {
    if (_image == null) return;
    setState(() => _results = 'Đang gửi ảnh...');

    try {
      final uri = Uri.parse('$baseUrl/search');
      final req = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', _image!.path));

      final res = await req.send();
      final body = await res.stream.bytesToString();

      if (res.statusCode == 200) {
        final data = json.decode(body);
        // In thử 1 phần tử để kiểm tra path
        if (data is List && data.isNotEmpty) {
          // ví dụ: {path: fox/fox_0037.jpg, distance: 0.123}
          // ignore: avoid_print
          print('SAMPLE RESULT => ${data.first}');
        }
        setState(() => _results = data);
      } else {
        setState(() => _results = 'Lỗi ${res.statusCode}: $body');
      }
    } catch (e) {
      setState(() => _results = 'Lỗi gửi yêu cầu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Scaffold(
      appBar: AppBar(title: const Text('Search with Image')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _image != null
                ? Image.file(_image!, height: 200)
                : const Text('Chưa chọn ảnh'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: pickImage, child: const Text('Chọn ảnh')),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: sendImageToAPI, child: const Text('Gửi ảnh')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: results == null
                  ? const Text('Kết quả sẽ hiển thị ở đây')
                  : results is String
                  ? SingleChildScrollView(child: Text(results))
                  : _buildResults(results as List),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(List list) {
    final int itemCount = list.length > 10 ? 10 : list.length;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        final item = list[i];
        final String path = item['path'].toString(); // ví dụ: fox/fox_0037.jpg
        final String imgUrl = '$baseUrl/dataset/$path';
        final double score = (item['distance'] as num).toDouble();

        // In URL để test nhanh: copy URL này dán vào trình duyệt xem có hiện ảnh không
        // ignore: avoid_print
        print('IMG URL => $imgUrl');

        return Column(
          children: [
            Expanded(
              child: Image.network(
                imgUrl,
                fit: BoxFit.cover,
                // Hiển thị vòng tròn loading khi đang tải
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      height: 28, width: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                // In lỗi ra console nếu tải ảnh thất bại
                errorBuilder: (context, err, stack) {
                  // ignore: avoid_print
                  print('IMG ERROR for $imgUrl => $err');
                  return const Icon(Icons.broken_image, size: 48);
                },
              ),
            ),
            const SizedBox(height: 4),
            Text('Score: ${score.toStringAsFixed(3)}',
                style: const TextStyle(fontSize: 12)),
          ],
        );
      },
    );
  }
}
