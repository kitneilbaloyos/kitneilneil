import 'package:flutter/material.dart';
import 'screens/file_upload_screen.dart';

void main() {
  runApp(const StudySmartApp());
}

class StudySmartApp extends StatelessWidget {
  const StudySmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudySmart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const FileUploadScreen(),
    );
  }
}
