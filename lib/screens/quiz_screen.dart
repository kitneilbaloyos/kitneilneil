import 'package:flutter/material.dart';
import '../services/groq_service.dart';

class QuizScreen extends StatefulWidget {
  final List<QuizQuestion> questions;
  final String fileName;

  const QuizScreen({
    super.key,
    required this.questions,
    required this.fileName,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  List<int?> _userAnswers = [];
  List<String?> _userTextAnswers = []; // For enumeration questions
  bool _showResults = false;
  bool _showExplanation = false;
  bool _answerChecked = false;
  final TextEditingController _textAnswerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userAnswers = List.filled(widget.questions.length, null);
    _userTextAnswers = List.filled(widget.questions.length, null);
    _textAnswerController.text = _userTextAnswers[_currentQuestionIndex] ?? '';
  }

  @override
  void dispose() {
    _textAnswerController.dispose();
    super.dispose();
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = answerIndex;
      _answerChecked = false;
      _showExplanation = false;
    });
  }

  void _updateTextAnswer(String answer) {
    setState(() {
      _userTextAnswers[_currentQuestionIndex] = answer;
      _answerChecked = false;
      _showExplanation = false;
    });
  }

  void _checkAnswer() {
    setState(() {
      _answerChecked = true;
    });
  }

  bool _isAnswerSelected() {
    final question = widget.questions[_currentQuestionIndex];
    switch (question.type) {
      case QuizType.multipleChoice:
      case QuizType.trueFalse:
        return _userAnswers[_currentQuestionIndex] != null;
      case QuizType.enumeration:
        return _userTextAnswers[_currentQuestionIndex] != null && 
               _userTextAnswers[_currentQuestionIndex]!.trim().isNotEmpty;
    }
  }

  bool _isAnswerCorrect() {
    final question = widget.questions[_currentQuestionIndex];
    switch (question.type) {
      case QuizType.multipleChoice:
      case QuizType.trueFalse:
        return _userAnswers[_currentQuestionIndex] == question.correctAnswerIndex;
      case QuizType.enumeration:
        final userAnswer = _userTextAnswers[_currentQuestionIndex]?.trim().toLowerCase() ?? '';
        final correctAnswer = question.correctAnswer?.trim().toLowerCase() ?? '';
        return userAnswer == correctAnswer;
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _showExplanation = false;
        _answerChecked = false;
        _textAnswerController.text = _userTextAnswers[_currentQuestionIndex] ?? '';
      });
    } else {
      setState(() {
        _showResults = true;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _showExplanation = false;
        _answerChecked = false;
        _textAnswerController.text = _userTextAnswers[_currentQuestionIndex] ?? '';
      });
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _userAnswers = List.filled(widget.questions.length, null);
      _userTextAnswers = List.filled(widget.questions.length, null);
      _showResults = false;
      _showExplanation = false;
      _answerChecked = false;
      _textAnswerController.clear();
    });
  }

  QuizResult _calculateResults() {
    int score = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      final question = widget.questions[i];
      bool isCorrect = false;
      
      switch (question.type) {
        case QuizType.multipleChoice:
        case QuizType.trueFalse:
          isCorrect = _userAnswers[i] == question.correctAnswerIndex;
          break;
        case QuizType.enumeration:
          final userAnswer = _userTextAnswers[i]?.trim().toLowerCase() ?? '';
          final correctAnswer = question.correctAnswer?.trim().toLowerCase() ?? '';
          isCorrect = userAnswer == correctAnswer;
          break;
      }
      
      if (isCorrect) {
        score++;
      }
    }
    return QuizResult(
      questions: widget.questions,
      score: score,
      totalQuestions: widget.questions.length,
      userAnswers: _userAnswers.map((e) => e ?? -1).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showResults) {
      return _buildResultsScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/img/logo_transparent.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/img/logo.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.quiz,
                          size: 20,
                          color: Colors.white,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Quiz: ${widget.fileName}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
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
            child: Column(
              children: [
              // Fixed Progress Bar
                Container(
                  padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(20),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Question ${_currentQuestionIndex + 1} of ${widget.questions.length}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            '${((_currentQuestionIndex + 1) / widget.questions.length * 100).round()}%',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      LinearProgressIndicator(
                        value: (_currentQuestionIndex + 1) / widget.questions.length,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                        minHeight: 8,
                      ),
                    ],
                  ),
                ),
                
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                // Question Card
                      Container(
                    padding: const EdgeInsets.all(25),
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
                        // Question
                        Text(
                          widget.questions[_currentQuestionIndex].question,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                            height: 1.4,
                          ),
                        ),
                        
                        const SizedBox(height: 25),
                        
                        // Answer Input (varies by question type)
                        _buildAnswerInput(),
                          ],
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
                
              // Fixed Check Answer and Explanation Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Check Button
                    if (_isAnswerSelected() && !_answerChecked)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Center(
                          child: ElevatedButton.icon(
                            onPressed: _checkAnswer,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Check Answer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    // Explanation Toggle (only show after checking)
                    if (_answerChecked)
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              _showExplanation ? 'Hide explanation' : 'Show explanation',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: _showExplanation ? 'Hide explanation' : 'Show explanation',
                              style: ButtonStyle(
                                backgroundColor: MaterialStatePropertyAll<Color>(Colors.blue[50]!),
                                foregroundColor: MaterialStatePropertyAll<Color>(Colors.blue[700]!),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showExplanation = !_showExplanation;
                                });
                              },
                              icon: Icon(_showExplanation ? Icons.visibility_off : Icons.visibility),
                            ),
                          ],
                        ),
                      ),

                    // Explanation Panel (only show after checking and if toggled)
                    if (_showExplanation && _answerChecked)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb, color: Colors.blue[600], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Explanation',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.questions[_currentQuestionIndex].explanation,
                              style: TextStyle(
                                color: Colors.blue[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
                
              // Fixed Navigation Buttons
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _answerChecked
                            ? _nextQuestion
                            : null,
                        icon: Icon(_currentQuestionIndex == widget.questions.length - 1
                            ? Icons.check
                            : Icons.arrow_forward),
                        label: Text(_currentQuestionIndex == widget.questions.length - 1
                            ? 'Finish'
                            : 'Next'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerInput() {
    final question = widget.questions[_currentQuestionIndex];
    
    switch (question.type) {
      case QuizType.multipleChoice:
        return _buildMultipleChoiceInput(question);
      case QuizType.enumeration:
        return _buildEnumerationInput(question);
      case QuizType.trueFalse:
        return _buildTrueFalseInput(question);
    }
  }

  Widget _buildMultipleChoiceInput(QuizQuestion question) {
    return Column(
      children: List.generate(
        question.choices.length,
        (index) {
          final isSelected = _userAnswers[_currentQuestionIndex] == index;
          final isCorrect = index == question.correctAnswerIndex;
          final showCorrectAnswer = _answerChecked;
          
          Color backgroundColor = Colors.white;
          Color borderColor = Colors.grey[300]!;
          Color textColor = Colors.grey[800]!;
          
          if (showCorrectAnswer) {
            if (isCorrect) {
              backgroundColor = Colors.green[50]!;
              borderColor = Colors.green[300]!;
              textColor = Colors.green[700]!;
            } else if (isSelected && !isCorrect) {
              backgroundColor = Colors.red[50]!;
              borderColor = Colors.red[300]!;
              textColor = Colors.red[700]!;
            }
          } else if (isSelected) {
            backgroundColor = Colors.blue[50]!;
            borderColor = Colors.blue[300]!;
            textColor = Colors.blue[700]!;
          }
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: _answerChecked ? null : () => _selectAnswer(index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? borderColor : Colors.transparent,
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      child: isSelected
                          ? Icon(
                              showCorrectAnswer && isCorrect
                                  ? Icons.check
                                  : Icons.circle,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${String.fromCharCode(65 + index)}. ${question.choices[index]}',
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (showCorrectAnswer && isCorrect)
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[600],
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnumerationInput(QuizQuestion question) {
    final userAnswer = _userTextAnswers[_currentQuestionIndex] ?? '';
    final showCorrectAnswer = _answerChecked;
    final isCorrect = _isAnswerCorrect();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: showCorrectAnswer 
            ? (isCorrect ? Colors.green[50] : Colors.red[50])
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: showCorrectAnswer 
              ? (isCorrect ? Colors.green[300]! : Colors.red[300]!)
              : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Answer:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textAnswerController,
            enabled: !_answerChecked,
            onChanged: _updateTextAnswer,
            decoration: InputDecoration(
              hintText: 'Type your answer here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          if (showCorrectAnswer) ...[
            const SizedBox(height: 12),
            Text(
              'Correct Answer: ${question.correctAnswer ?? 'N/A'}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isCorrect ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrueFalseInput(QuizQuestion question) {
    return Row(
      children: [
        Expanded(
          child: _buildTrueFalseOption(question, 0, 'True'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTrueFalseOption(question, 1, 'False'),
        ),
      ],
    );
  }

  Widget _buildTrueFalseOption(QuizQuestion question, int index, String label) {
    final isSelected = _userAnswers[_currentQuestionIndex] == index;
    final isCorrect = index == question.correctAnswerIndex;
    final showCorrectAnswer = _answerChecked;
    
    Color backgroundColor = Colors.white;
    Color borderColor = Colors.grey[300]!;
    Color textColor = Colors.grey[800]!;
    
    if (showCorrectAnswer) {
      if (isCorrect) {
        backgroundColor = Colors.green[50]!;
        borderColor = Colors.green[300]!;
        textColor = Colors.green[700]!;
      } else if (isSelected && !isCorrect) {
        backgroundColor = Colors.red[50]!;
        borderColor = Colors.red[300]!;
        textColor = Colors.red[700]!;
      }
    } else if (isSelected) {
      backgroundColor = Colors.blue[50]!;
      borderColor = Colors.blue[300]!;
      textColor = Colors.blue[700]!;
    }
    
    return InkWell(
      onTap: _answerChecked ? null : () => _selectAnswer(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          children: [
            Icon(
              label == 'True' ? Icons.check_circle : Icons.cancel,
              size: 32,
              color: textColor,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (showCorrectAnswer && isCorrect)
              Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    final results = _calculateResults();
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/img/logo_transparent.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/img/logo.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.quiz,
                          size: 20,
                          color: Colors.white,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Quiz Results'),
          ],
        ),
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
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Score Card
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        results.percentage >= 70 ? Icons.celebration : Icons.school,
                        size: 80,
                        color: results.percentage >= 70 ? Colors.green[600] : Colors.orange[600],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        results.percentage >= 70 ? 'Great Job!' : 'Keep Learning!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'You scored ${results.score} out of ${results.totalQuestions}',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${results.percentage.round()}%',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: results.percentage >= 70 ? Colors.green[600] : Colors.orange[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.home),
                        label: const Text('New File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _restartQuiz,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Quiz'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Review Section
                Expanded(
                  child: Container(
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
                          'Review Your Answers',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Expanded(
                          child: ListView.builder(
                            itemCount: results.questions.length,
                            itemBuilder: (context, index) {
                              final question = results.questions[index];
                              final userAnswer = results.userAnswers[index];
                              final isCorrect = userAnswer == question.correctAnswerIndex;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: isCorrect ? Colors.green[50] : Colors.red[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCorrect ? Colors.green[200]! : Colors.red[200]!,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isCorrect ? Icons.check_circle : Icons.cancel,
                                          color: isCorrect ? Colors.green[600] : Colors.red[600],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Question ${index + 1}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isCorrect ? Colors.green[700] : Colors.red[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      question.question,
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Your answer: ${userAnswer >= 0 ? String.fromCharCode(65 + userAnswer) : 'Not answered'}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Correct answer: ${String.fromCharCode(65 + question.correctAnswerIndex)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
