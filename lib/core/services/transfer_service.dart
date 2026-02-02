import 'dart:io';
import 'package:flutter/foundation.dart';

class TransferService {
  HttpServer? _server;
  final int port = 8080;

  Future<String?> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting IP: $e');
      return null;
    }
  }

  Future<void> startServer(List<File> filesToShare) async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('Server started on port $port');

      _server!.listen((HttpRequest request) async {
        final path = request.uri.path;

        if (path == '/') {
          // Serve item list
          request.response
            ..headers.contentType = ContentType.html
            ..write(_buildHtmlList(filesToShare))
            ..close();
        } else if (path.startsWith('/file/')) {
          // Serve specific file
          final fileName = Uri.decodeComponent(path.substring(6));
          try {
            final file = filesToShare.firstWhere(
              (f) => f.path.split('/').last == fileName,
            );

            request.response
              ..headers.contentType = _getContentType(fileName)
              ..headers.contentLength = await file.length()
              ..headers.add(
                'Content-Disposition',
                'attachment; filename="$fileName"',
              );

            await file.openRead().pipe(request.response);
          } catch (e) {
            request.response
              ..statusCode = HttpStatus.notFound
              ..close();
          }
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });
    } catch (e) {
      debugPrint('Error starting server: $e');
    }
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  String _buildHtmlList(List<File> files) {
    String list = '<h1>Shared Files</h1><ul>';
    for (var file in files) {
      final name = file.path.split('/').last;
      list += '<li><a href="/file/${Uri.encodeComponent(name)}">$name</a></li>';
    }
    list += '</ul>';
    return '<html><body>$list</body></html>';
  }

  ContentType _getContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
        return ContentType('video', 'mp4');
      case 'mkv':
        return ContentType('video', 'x-matroska');
      case 'mp3':
        return ContentType('audio', 'mpeg');
      default:
        return ContentType.binary;
    }
  }
}
