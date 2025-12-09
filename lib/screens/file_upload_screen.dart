import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/text_extractor.dart';
import '../services/groq_service.dart';
import 'quiz_screen.dart';

class FileUploadScreen extends StatefulWidget {
  const FileUploadScreen({super.key});

  @override
  State<FileUploadScreen> createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  String? _selectedFilePath;
  double _fileSize = 0.0;
  Uint8List? _selectedFileBytes;
  int _selectedQuestionCount = 5;
  QuizType _selectedQuizType = QuizType.multipleChoice;

  @override
  void initState() {
    super.initState();
    _checkApiKeyStatus();
  }

  void _checkApiKeyStatus() {
    if (!GroqService.isApiKeyConfigured) {
      setState(() {
        _statusMessage = 'Warning: Groq API key not configured. Please run with --dart-define=GROQ_API_KEY=your_key';
      });
    }
  }

  Future<bool> _requestFilePermissions() async {
    try {
      // Request storage permission (works for most Android versions)
      final storagePermission = await Permission.storage.request();
      
      // Request photos permission for Android 13+ (API 33+)
      final photosPermission = await Permission.photos.request();
      
      // Request camera permission for image capture
      final cameraPermission = await Permission.camera.request();
      
      // Check if we have at least one of the required permissions
      bool hasStorageAccess = storagePermission == PermissionStatus.granted || 
                             photosPermission == PermissionStatus.granted;
      
      if (!hasStorageAccess) {
        // Try manage external storage for broader file access (Android 11+)
        final manageStoragePermission = await Permission.manageExternalStorage.request();
        hasStorageAccess = manageStoragePermission == PermissionStatus.granted;
      }
      
      return hasStorageAccess;
    } catch (e) {
      // If permission request fails, try basic storage permission
      try {
        final storagePermission = await Permission.storage.request();
        return storagePermission == PermissionStatus.granted;
      } catch (e2) {
        return false;
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Checking permissions...';
      });

      // Request permissions based on Android version
      bool hasRequiredPermissions = await _requestFilePermissions();
      
      if (!hasRequiredPermissions) {
        setState(() {
          _statusMessage = 'File access permissions are required. Please go to Settings > Apps > StudySmart > Permissions and enable Storage/Photos access.';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Selecting file...';
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'pptx', 'txt', 'jpg', 'jpeg', 'png', 'bmp', 'gif'],
        allowMultiple: false,
        withData: true, // This ensures we get file bytes
        allowCompression: false, // Prevent compression issues
        lockParentWindow: false, // Better compatibility
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final extension = file.name.toLowerCase().split('.').last;
        final isImage = ['jpg', 'jpeg', 'png', 'bmp', 'gif'].contains(extension);
        final fileSizeMB = file.size / (1024 * 1024);
        
        // Check for large files and show warning
        String warningMessage = '';
        if (fileSizeMB > 10) {
          warningMessage = '\n⚠️ Warning: Large file detected (${fileSizeMB.toStringAsFixed(2)} MB). Processing may take longer and hit API limits.';
        } else if (fileSizeMB > 5) {
          warningMessage = '\n⚠️ Note: File size is ${fileSizeMB.toStringAsFixed(2)} MB. Large files may take longer to process.';
        }
        
        // For images, prioritize file path over bytes (ML Kit needs actual file path)
        if (isImage && file.path != null) {
          setState(() {
            _selectedFilePath = file.path!;
            _fileSize = fileSizeMB;
            _selectedFileBytes = null; // Don't use bytes for images
            _statusMessage = 'File selected: ${file.name} (${fileSizeMB.toStringAsFixed(2)} MB)$warningMessage';
          });
        } else if (file.bytes != null) {
          setState(() {
            _selectedFilePath = file.path ?? 'web_file_${file.name}';
            _fileSize = fileSizeMB;
            _selectedFileBytes = file.bytes;
            _statusMessage = 'File selected: ${file.name} (${fileSizeMB.toStringAsFixed(2)} MB)$warningMessage';
          });
        } else {
          setState(() {
            _statusMessage = 'Error: Could not access file data. Please try selecting the file again.';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'No file selected';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error selecting file: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processFile() async {
    if (_selectedFilePath == null) {
      setState(() {
        _statusMessage = 'Please select a file first';
      });
      return;
    }

    if (!GroqService.isApiKeyConfigured) {
      setState(() {
        _statusMessage = 'Cannot process file: Groq API key not configured';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Extracting text from file...';
      });

      // Extract text from file (handles both web bytes and file paths)
      // Use chunking for large files to avoid API limits
      String extractedText;
      final extension = _selectedFilePath!.toLowerCase().split('.').last;
      
      if (_fileSize > 5 || extension == 'pptx' || extension == 'pdf') {
        // Use chunking for large files or problematic formats
        setState(() {
          _statusMessage = 'Processing large file with chunking...';
        });
        
        int? maxSlides;
        if (extension == 'pptx' && _fileSize > 10) {
          maxSlides = 5; // Limit PPTX to first 5 slides for very large files
          setState(() {
            _statusMessage = 'Processing large PPTX file (limiting to first 5 slides)...';
          });
        }
        
        extractedText = await TextExtractor.processLargeFile(
          _selectedFilePath!, 
          fileBytes: _selectedFileBytes,
          maxSlides: maxSlides
        );
      } else {
        // Use regular extraction for smaller files
        extractedText = await TextExtractor.extractText(
          _selectedFilePath!, 
          fileBytes: _selectedFileBytes
        );
      }
      
      if (extractedText.isEmpty) {
        setState(() {
          _statusMessage = 'No text could be extracted from the file';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Text extracted successfully. Generating $_selectedQuestionCount quiz questions...';
      });

      // Generate quiz questions
      final questions = await GroqService.generateQuiz(extractedText, numberOfQuestions: _selectedQuestionCount, quizType: _selectedQuizType);

      if (questions.isEmpty) {
        setState(() {
          _statusMessage = 'Failed to generate quiz questions';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Quiz generated successfully!';
      });

      // Navigate to quiz screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              questions: questions,
              fileName: _selectedFilePath!.split('/').last,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error processing file: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudySmart'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[600]!, Colors.blue[400]!],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            'assets/img/logo_transparent.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/img/logo.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.upload_file,
                                    size: 64,
                                    color: Colors.blue[600],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'StudySmart',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload Study Material',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload PDF, DOCX, PPTX, TXT, or image files to generate AI-powered quiz questions',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // File Selection
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Supported Formats',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFormatChip('PDF'),
                          _buildFormatChip('DOCX'),
                          _buildFormatChip('PPTX'),
                          _buildFormatChip('TXT'),
                          _buildFormatChip('Images'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _pickFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Select File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Selected File Info
                if (_selectedFilePath != null)
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[600]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'File Selected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                              Text(
                                _selectedFilePath!.split('/').last,
                                style: TextStyle(color: Colors.green[600]),
                              ),
                              Text(
                                'Size: ${_fileSize.toStringAsFixed(2)} MB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Question Count Selector
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Number of Questions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          _buildQuestionCountChip(5),
                          const SizedBox(width: 10),
                          _buildQuestionCountChip(10),
                          const SizedBox(width: 10),
                          _buildQuestionCountChip(15),
                          const SizedBox(width: 10),
                          _buildQuestionCountChip(20),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Quiz Type Selector
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildQuizTypeChip('Multiple Choice', QuizType.multipleChoice),
                          _buildQuizTypeChip('Enumeration', QuizType.enumeration),
                          _buildQuizTypeChip('True/False', QuizType.trueFalse),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Process Button
                ElevatedButton.icon(
                  onPressed: _isLoading || _selectedFilePath == null || _selectedFilePath!.isEmpty ? null : _processFile,
                  icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                  label: Text(_isLoading ? 'Processing...' : 'Generate Quiz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Status Message
                if (_statusMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _statusMessage.contains('Error') || _statusMessage.contains('Warning')
                          ? Colors.red[50]
                          : _statusMessage.contains('successfully')
                              ? Colors.green[50]
                              : Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _statusMessage.contains('Error') || _statusMessage.contains('Warning')
                            ? Colors.red[300]!
                            : _statusMessage.contains('successfully')
                                ? Colors.green[300]!
                                : Colors.blue[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _statusMessage.contains('Error') || _statusMessage.contains('Warning')
                              ? Icons.error
                              : _statusMessage.contains('successfully')
                                  ? Icons.check_circle
                                  : Icons.info,
                          color: _statusMessage.contains('Error') || _statusMessage.contains('Warning')
                              ? Colors.red[600]
                              : _statusMessage.contains('successfully')
                                  ? Colors.green[600]
                                  : Colors.blue[600],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              color: _statusMessage.contains('Error') || _statusMessage.contains('Warning')
                                  ? Colors.red[700]
                                  : _statusMessage.contains('successfully')
                                      ? Colors.green[700]
                                      : Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                
                // API Key Status
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'API Status: ${GroqService.apiKeyStatus}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatChip(String format) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        format,
        style: TextStyle(
          color: Colors.blue[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildQuestionCountChip(int count) {
    final isSelected = _selectedQuestionCount == count;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedQuestionCount = count;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildQuizTypeChip(String label, QuizType type) {
    final isSelected = _selectedQuizType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedQuizType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[600] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.green[600]! : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
