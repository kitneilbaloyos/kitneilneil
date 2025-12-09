# StudySmart - AI-Powered Quiz Generator

A Flutter application that allows users to upload study materials (PDF, DOCX, PPTX, TXT, images) and generates AI-powered quiz questions using Groq's Llama model.

## Features

- 📁 **File Upload**: Support for PDF, DOCX, PPTX, TXT, and image files
- 🔤 **Text Extraction**: Advanced text extraction from various file formats
- 🤖 **AI Quiz Generation**: Uses Groq's Llama-3.1-8B-Instant model to generate quiz questions
- 📱 **Interactive Quiz**: Beautiful UI with progress tracking and explanations
- 🎯 **Smart Scoring**: Detailed results with answer review
- 📊 **OCR Support**: Extract text from images using Google ML Kit

## Supported File Formats

- **DOCX**: Microsoft Word documents (full support)
- **TXT**: Plain text files (full support)
- **Images**: JPG, JPEG, PNG, BMP, GIF with OCR (full support)
- **PDF**: Basic support (fallback to text reading)
- **PPTX**: Limited support (shows message to convert to other formats)

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Run the App

The app now has the API key built-in for easy testing:

```bash
flutter run
```

**For production**: If you want to use your own API key, you can still override it:

```bash
flutter run --dart-define=GROQ_API_KEY=your_own_key
```

**Note**: The API key is already configured in the code for testing purposes.

### 3. Android Setup

The app is already configured for Android with:
- Minimum SDK version: 21 (required for ML Kit OCR)
- Permissions for camera and file access

### 4. Run the App

```bash
flutter run
```

## Usage

1. **Upload File**: Tap "Select File" to choose a study material
2. **Generate Quiz**: Tap "Generate Quiz" to create AI-powered questions
3. **Take Quiz**: Answer multiple choice questions with explanations
4. **Review Results**: See your score and review answers

## Technical Details

### Dependencies

- `file_picker`: File selection from device
- `docx_to_text`: DOCX text extraction
- `syncfusion_flutter_pdf`: PDF processing and PPTX conversion
- `google_mlkit_text_recognition`: OCR for images
- `groq`: Official Groq API client
- `flutter_spinkit`: Loading animations
- `shared_preferences`: Local storage

### Architecture

- **Services**: Text extraction and Groq API integration
- **Screens**: File upload and quiz display
- **Models**: Quiz question and result data structures

## API Configuration

The app uses Groq's Llama-3.1-8B-Instant model with the following configuration:
- Temperature: 0.7
- Max tokens: 2000
- Model: llama-3.1-8b-instant

## Error Handling

The app includes comprehensive error handling for:
- File format validation
- Text extraction failures
- API rate limits
- Network connectivity issues

## Security Notes

- API keys are passed via command line arguments (not hardcoded)
- File permissions are properly configured
- No sensitive data is stored locally

## Troubleshooting

### Common Issues

1. **API Key Error**: Make sure to run with `--dart-define=GROQ_API_KEY=your_key`
2. **File Selection Issues**: Ensure file permissions are granted
3. **Text Extraction Fails**: Check if the file format is supported and file is not corrupted

### Debug Mode

Run in debug mode for detailed error messages:

```bash
flutter run --debug --dart-define=GROQ_API_KEY=your_key
```

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is for educational purposes. Please ensure you comply with Groq's terms of service when using their API.