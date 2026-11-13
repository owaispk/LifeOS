// Inbox service: classification and handoff logic (PBI-026).

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../../money/data/expense_service.dart';
import '../../tasks/data/task_service.dart';
import '../../tasks/domain/nl_parser.dart';
import '../domain/capture_model.dart';
import 'captures_repo.dart';

/// Result of classifying a capture's content.
class ClassificationResult {
  const ClassificationResult({
    required this.suggestedType,
    this.parsedTask,
    this.suggestedAmount,
    this.confidence = 0.5,
  });

  final DestinationType suggestedType;
  final ParsedTask? parsedTask;
  final int? suggestedAmount;
  final double confidence;
}

/// Service for processing captures into their destinations.
class InboxService {
  InboxService(
    Repositories repos, {
    CapturesRepository? capturesRepo,
    TaskService? taskService,
    ExpenseService? expenseService,
    DateTime Function()? now,
  }) : _capturesRepo = capturesRepo ?? CapturesRepository(repos, now: now),
       _taskService = taskService ?? TaskService(repos, now: now),
       _expenseService = expenseService ?? ExpenseService(repos),
       _now = now ?? DateTime.now;

  final CapturesRepository _capturesRepo;
  final TaskService _taskService;
  final ExpenseService _expenseService;
  final DateTime Function() _now;

  CapturesRepository get captures => _capturesRepo;

  /// Suggests a classification based on the capture's content.
  ClassificationResult classify(Capture capture) {
    final text = capture.content ?? '';
    if (text.isEmpty && capture.type == CaptureType.photo) {
      return const ClassificationResult(
        suggestedType: DestinationType.document,
        confidence: 0.8,
      );
    }

    // Try parsing as a task using nl_parser
    final parsed = parseTask(text, _now());
    
    // Check for money signals
    if (parsed.domain == 'money' || parsed.amount != null) {
      final amount = _parseAmount(parsed.amount);
      if (amount != null) {
        return ClassificationResult(
          suggestedType: DestinationType.expense,
          parsedTask: parsed,
          suggestedAmount: amount,
          confidence: 0.7,
        );
      }
    }

    // Default to task if there's actionable content
    if (parsed.date != null || parsed.highPriority || text.length < 100) {
      return ClassificationResult(
        suggestedType: DestinationType.task,
        parsedTask: parsed,
        confidence: parsed.date != null ? 0.8 : 0.6,
      );
    }

    // Longer text defaults to note
    return ClassificationResult(
      suggestedType: DestinationType.note,
      parsedTask: parsed,
      confidence: 0.5,
    );
  }

  /// Creates a task from a capture.
  Future<Task> createTask(
    Capture capture, {
    String? title,
    DateTime? due,
    bool allDay = true,
    int priority = 1,
    String domain = 'mind',
    String? personId,
    String? notes,
  }) async {
    final parsed = parseTask(capture.content ?? '', _now());
    final taskTitle = title ?? parsed.title;
    final taskDue = due ?? parsed.dueAt(_now());
    final taskPriority = parsed.highPriority ? 2 : priority;
    final taskDomain = parsed.domain ?? domain;

    final task = await _taskService.create(
      title: taskTitle.isNotEmpty ? taskTitle : 'Untitled',
      due: taskDue,
      allDay: !parsed.hasTime && allDay,
      priority: taskPriority,
      domain: taskDomain,
      personId: personId,
      notes: notes ?? capture.notes,
    );

    await _capturesRepo.markProcessed(
      id: capture.id,
      destinationType: DestinationType.task,
      destinationId: task.id,
    );

    return task;
  }

  /// Creates an expense from a capture.
  Future<Expense> createExpense(
    Capture capture, {
    required int amountMinor,
    DateTime? spentOn,
    String? categoryId,
    String? note,
  }) async {
    final expense = await _expenseService.add(
      amountMinor: amountMinor,
      spentOn: spentOn ?? DateTime.now(),
      categoryId: categoryId,
      note: note ?? capture.content,
    );

    await _capturesRepo.markProcessed(
      id: capture.id,
      destinationType: DestinationType.expense,
      destinationId: expense.id,
    );

    return expense;
  }

  /// Dismisses a capture without creating anything.
  Future<Capture> dismiss(String captureId) {
    return _capturesRepo.delete(captureId);
  }

  /// Undoes a dismiss.
  Future<Capture> undoDismiss(String captureId) {
    return _capturesRepo.restore(captureId);
  }

  /// Adds a text capture.
  Future<Capture> addText(String content) {
    return _capturesRepo.createText(content);
  }

  /// Adds a voice capture (transcribed text).
  Future<Capture> addVoice(String transcription, {String? audioPath}) {
    return _capturesRepo.createVoice(transcription, mediaPath: audioPath);
  }

  /// Adds a photo capture.
  Future<Capture> addPhoto(String imagePath, {String? mime, int? sizeBytes}) {
    return _capturesRepo.createPhoto(
      mediaPath: imagePath,
      mediaMime: mime,
      mediaSizeBytes: sizeBytes,
    );
  }

  /// Adds a file capture.
  Future<Capture> addFile(String filePath, {String? mime, int? sizeBytes}) {
    return _capturesRepo.createFile(
      mediaPath: filePath,
      mediaMime: mime,
      mediaSizeBytes: sizeBytes,
    );
  }

  int? _parseAmount(String? amountStr) {
    if (amountStr == null) return null;
    // Remove currency symbols and commas
    final cleaned = amountStr
        .replaceAll(RegExp(r'[Rs\.PKRINRrs₨,/-]', caseSensitive: false), '')
        .trim();
    final value = int.tryParse(cleaned);
    if (value != null && value > 0) {
      return value * 100; // Convert to minor units
    }
    return null;
  }
}
