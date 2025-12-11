import 'dart:convert';
import 'package:http/http.dart' as http;

enum QuizType {
  multipleChoice,
  enumeration,
  trueFalse,
}

class QuizQuestion {
  final String question;
  final List<String> choices;
  final int correctAnswerIndex;
  final String explanation;
  final QuizType type;
  final String? correctAnswer; // For enumeration questions
  final bool? isTrue; // For true/false questions

  QuizQuestion({
    required this.question,
    required this.choices,
    required this.correctAnswerIndex,
    required this.explanation,
    required this.type,
    this.correctAnswer,
    this.isTrue,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? '',
      choices: List<String>.from(json['choices'] ?? []),
      correctAnswerIndex: json['correct_answer_index'] ?? 0,
      explanation: json['explanation'] ?? '',
      type: _parseQuizType(json['type'] ?? 'multiple_choice'),
      correctAnswer: json['correct_answer'],
      isTrue: json['is_true'],
    );
  }

  static QuizType _parseQuizType(String type) {
    switch (type.toLowerCase()) {
      case 'enumeration':
        return QuizType.enumeration;
      case 'true_false':
        return QuizType.trueFalse;
      default:
        return QuizType.multipleChoice;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'choices': choices,
      'correct_answer_index': correctAnswerIndex,
      'explanation': explanation,
      'type': type.name,
      'correct_answer': correctAnswer,
      'is_true': isTrue,
    };
  }
}

class QuizResult {
  final List<QuizQuestion> questions;
  final int score;
  final int totalQuestions;
  final List<int> userAnswers;

  QuizResult({
    required this.questions,
    required this.score,
    required this.totalQuestions,
    required this.userAnswers,
  });

  double get percentage => totalQuestions > 0 ? (score / totalQuestions) * 100 : 0.0;
}

class GroqService {
  // Use environment variable if available, otherwise use hardcoded key for testing
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: 'SECRET_API__KEY_HEHEHEHE');
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant';

  /// Generate quiz questions from extracted text
  static Future<List<QuizQuestion>> generateQuiz(String text, {int numberOfQuestions = 5, QuizType quizType = QuizType.multipleChoice}) async {
    if (_apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY not found. Please check the API key configuration.');
    }

    try {
      final prompt = _buildQuizPrompt(text, numberOfQuestions, quizType);
      final response = await _callGroqAPI(prompt);
      return _parseQuizResponse(response, quizType);
    } catch (e) {
      throw Exception('Failed to generate quiz: $e');
    }
  }

  /// Build the prompt for quiz generation
  static String _buildQuizPrompt(String text, int numberOfQuestions, QuizType quizType) {
    switch (quizType) {
      case QuizType.multipleChoice:
        return _buildMultipleChoicePrompt(text, numberOfQuestions);
      case QuizType.enumeration:
        return _buildEnumerationPrompt(text, numberOfQuestions);
      case QuizType.trueFalse:
        return _buildTrueFalsePrompt(text, numberOfQuestions);
    }
  }

  static String _buildMultipleChoicePrompt(String text, int numberOfQuestions) {
    return '''
You are an expert educator who creates high-quality multiple choice questions for studying purposes.

Based on the following text, create exactly $numberOfQuestions multiple choice questions that test understanding of the key concepts.

Text to analyze:
$text

Requirements:
1. Create exactly $numberOfQuestions questions
2. Each question should have exactly 4 answer choices (A, B, C, D)
3. Questions should test comprehension, analysis, and application of concepts
4. Include one clearly correct answer and three plausible distractors
5. Provide a brief explanation for each correct answer

IMPORTANT: Return ONLY a valid JSON array. Do not include any text before or after the JSON.

Return this exact JSON structure:
[
  {
    "question": "Your question here?",
    "choices": ["Option A", "Option B", "Option C", "Option D"],
    "correct_answer_index": 0,
    "explanation": "Brief explanation of why this answer is correct",
    "type": "multiple_choice"
  }
]

The correct_answer_index should be 0, 1, 2, or 3 corresponding to the position in the choices array.
''';
  }

  static String _buildEnumerationPrompt(String text, int numberOfQuestions) {
    return '''
You are an expert educator who creates high-quality enumeration (fill-in-the-blank) questions for studying purposes.

Based on the following text, create exactly $numberOfQuestions enumeration questions that test understanding of the key concepts.

Text to analyze:
$text

Requirements:
1. Create exactly $numberOfQuestions questions
2. Each question should ask for a specific answer that can be typed in
3. Questions should test recall and understanding of key terms, concepts, or facts
4. Provide the exact correct answer (case-sensitive)
5. Provide a brief explanation for each correct answer

IMPORTANT: Return ONLY a valid JSON array. Do not include any text before or after the JSON.

Return this exact JSON structure:
[
  {
    "question": "What is the term for [concept]?",
    "choices": ["", "", "", ""],
    "correct_answer_index": 0,
    "correct_answer": "Exact Answer",
    "explanation": "Brief explanation of why this answer is correct",
    "type": "enumeration"
  }
]

The correct_answer should be the exact text that the user needs to type to get the question right.
''';
  }

  static String _buildTrueFalsePrompt(String text, int numberOfQuestions) {
    return '''
You are an expert educator who creates high-quality true/false questions for studying purposes.

Based on the following text, create exactly $numberOfQuestions true/false questions that test understanding of the key concepts.

Text to analyze:
$text

Requirements:
1. Create exactly $numberOfQuestions questions
2. Each question should be a clear statement that can be evaluated as true or false
3. Questions should test comprehension and critical thinking
4. Mix of true and false statements
5. Provide a brief explanation for each correct answer

IMPORTANT: Return ONLY a valid JSON array. Do not include any text before or after the JSON.

Return this exact JSON structure:
[
  {
    "question": "Statement that can be true or false",
    "choices": ["True", "False"],
    "correct_answer_index": 0,
    "is_true": true,
    "explanation": "Brief explanation of why this answer is correct",
    "type": "true_false"
  }
]

The correct_answer_index should be 0 for True or 1 for False. The is_true field should match the correct answer.
''';
  }

  /// Call the Groq API
  static Future<String> _callGroqAPI(String prompt) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a helpful AI assistant that creates educational content. Always respond with valid JSON when requested.'
          },
          {
            'role': 'user',
            'content': prompt
          }
        ],
        'temperature': 0.7,
        'max_tokens': 2000,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('API request failed with status ${response.statusCode}: ${response.body}');
    }
    
    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] ?? '';
  }

  /// Parse the quiz response from Groq
  static List<QuizQuestion> _parseQuizResponse(String response, QuizType quizType) {
    try {
      // Clean the response to extract JSON
      String jsonString = response.trim();
      
      // Remove common prefixes that AI might add
      final prefixes = [
        'Here are 5 multiple choice questions based on the provided text:',
        'Here are 5 multiple choice questions:',
        'Here are the quiz questions:',
        'Here are the questions:',
        'Quiz questions:',
        'Questions:',
      ];
      
      for (final prefix in prefixes) {
        if (jsonString.startsWith(prefix)) {
          jsonString = jsonString.substring(prefix.length).trim();
          break;
        }
      }
      
      // Remove markdown code blocks if present
      if (jsonString.startsWith('```json')) {
        jsonString = jsonString.substring(7);
      }
      if (jsonString.startsWith('```')) {
        jsonString = jsonString.substring(3);
      }
      if (jsonString.endsWith('```')) {
        jsonString = jsonString.substring(0, jsonString.length - 3);
      }
      
      jsonString = jsonString.trim();
      
      // Find the first '[' character to start of JSON array
      final startIndex = jsonString.indexOf('[');
      if (startIndex != -1) {
        jsonString = jsonString.substring(startIndex);
      }
      
      // Find the last ']' character to end of JSON array
      final lastIndex = jsonString.lastIndexOf(']');
      if (lastIndex != -1) {
        jsonString = jsonString.substring(0, lastIndex + 1);
      }
      
      // Try to fix common JSON issues
      jsonString = _fixJsonIssues(jsonString);
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final List<QuizQuestion> questions = [];
      
      for (final item in jsonList) {
        if (item is Map<String, dynamic>) {
          questions.add(QuizQuestion.fromJson(item));
        }
      }
      
      if (questions.isEmpty) {
        throw Exception('No valid questions found in response');
      }
      
      return questions;
    } catch (e) {
      // If JSON parsing fails, try to extract questions manually
      try {
        return _extractQuestionsManually(response);
      } catch (e2) {
        throw Exception('Failed to parse quiz response: $e\nResponse: $response');
      }
    }
  }

  /// Fix common JSON issues in AI responses
  static String _fixJsonIssues(String jsonString) {
    // Fix missing closing braces
    int openBraces = 0;
    int openBrackets = 0;
    
    for (int i = 0; i < jsonString.length; i++) {
      if (jsonString[i] == '{') openBraces++;
      if (jsonString[i] == '}') openBraces--;
      if (jsonString[i] == '[') openBrackets++;
      if (jsonString[i] == ']') openBrackets--;
    }
    
    // Add missing closing braces
    while (openBraces > 0) {
      jsonString += '}';
      openBraces--;
    }
    
    // Add missing closing brackets
    while (openBrackets > 0) {
      jsonString += ']';
      openBrackets--;
    }
    
    // Fix common quote issues
    jsonString = jsonString.replaceAll("'", '"');
    
    // Fix trailing commas
    jsonString = jsonString.replaceAll(RegExp(r',\s*}'), '}');
    jsonString = jsonString.replaceAll(RegExp(r',\s*]'), ']');
    
    return jsonString;
  }

  /// Extract questions manually if JSON parsing fails
  static List<QuizQuestion> _extractQuestionsManually(String response) {
    final List<QuizQuestion> questions = [];
    
    // Split by question patterns
    final questionPattern = RegExp(r'"question":\s*"([^"]+)"');
    final choicePattern = RegExp(r'"choices":\s*\[([^\]]+)\]');
    final answerPattern = RegExp(r'"correct_answer_index":\s*(\d+)');
    final explanationPattern = RegExp(r'"explanation":\s*"([^"]+)"');
    
    final questionMatches = questionPattern.allMatches(response);
    final choiceMatches = choicePattern.allMatches(response);
    final answerMatches = answerPattern.allMatches(response);
    final explanationMatches = explanationPattern.allMatches(response);
    
    final questionList = questionMatches.map((m) => m.group(1)!).toList();
    final choiceList = choiceMatches.map((m) => m.group(1)!).toList();
    final answerList = answerMatches.map((m) => int.parse(m.group(1)!)).toList();
    final explanationList = explanationMatches.map((m) => m.group(1)!).toList();
    
    for (int i = 0; i < questionList.length; i++) {
      if (i < choiceList.length && i < answerList.length && i < explanationList.length) {
        // Parse choices
        final choicesString = choiceList[i];
        final choices = choicesString
            .split(',')
            .map((c) => c.trim().replaceAll('"', ''))
            .toList();
        
        questions.add(QuizQuestion(
          question: questionList[i],
          choices: choices,
          correctAnswerIndex: answerList[i],
          explanation: explanationList[i],
          type: QuizType.multipleChoice,
        ));
      }
    }
    
    if (questions.isEmpty) {
      throw Exception('Could not extract any questions from response');
    }
    
    return questions;
  }

  /// Generate a study summary from text
  static Future<String> generateSummary(String text) async {
    if (_apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY not found. Please check the API key configuration.');
    }

    try {
      final prompt = '''
Based on the following text, create a comprehensive study summary that highlights the key concepts, main ideas, and important details.

Text:
$text

Please provide:
1. Key concepts and definitions
2. Main ideas and themes
3. Important details and examples
4. Connections between different parts

Format the summary in a clear, organized manner that would be helpful for studying.
''';
      
      final response = await _callGroqAPI(prompt);
      return response.trim();
    } catch (e) {
      throw Exception('Failed to generate summary: $e');
    }
  }

  /// Generate flashcards from text
  static Future<List<Map<String, String>>> generateFlashcards(String text, {int numberOfCards = 10}) async {
    if (_apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY not found. Please check the API key configuration.');
    }

    try {
      final prompt = '''
Based on the following text, create exactly $numberOfCards flashcards that would be useful for studying.

Text:
$text

Return your response as a valid JSON array with this exact structure:
[
  {
    "front": "Question or term",
    "back": "Answer or definition"
  }
]

Make sure the JSON is valid and properly formatted.
''';
      
      final response = await _callGroqAPI(prompt);
      final jsonString = _cleanJsonResponse(response);
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      return jsonList.map((item) => <String, String>{
        'front': item['front']?.toString() ?? '',
        'back': item['back']?.toString() ?? '',
      }).toList();
    } catch (e) {
      throw Exception('Failed to generate flashcards: $e');
    }
  }

  /// Clean JSON response by removing markdown formatting
  static String _cleanJsonResponse(String response) {
    String jsonString = response.trim();
    
    // Remove markdown code blocks if present
    if (jsonString.startsWith('```json')) {
      jsonString = jsonString.substring(7);
    }
    if (jsonString.startsWith('```')) {
      jsonString = jsonString.substring(3);
    }
    if (jsonString.endsWith('```')) {
      jsonString = jsonString.substring(0, jsonString.length - 3);
    }
    
    return jsonString.trim();
  }

  /// Check if API key is configured
  static bool get isApiKeyConfigured => _apiKey.isNotEmpty;

  /// Get API key status for debugging
  static String get apiKeyStatus => _apiKey.isEmpty ? 'Not configured' : 'Configured (${_apiKey.length} characters)';
}
