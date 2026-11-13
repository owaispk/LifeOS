// Classification modal for Task/Expense/Document/Note (PBI-026).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/db/app_database.dart';
import '../../money/domain/money_rules.dart' show categoryName, colorSlotFor;
import '../../money/money_providers.dart';
import '../../money/ui/category_colors.dart';
import '../../tasks/domain/nl_parser.dart';
import '../data/inbox_service.dart';
import '../domain/capture_model.dart';
import '../inbox_providers.dart';

/// Modal for classifying a capture into Task, Expense, Document, or Note.
class ClassifyModal extends ConsumerStatefulWidget {
  const ClassifyModal({super.key, required this.capture});

  final Capture capture;

  @override
  ConsumerState<ClassifyModal> createState() => _ClassifyModalState();
}

class _ClassifyModalState extends ConsumerState<ClassifyModal> {
  late DestinationType _selectedType;
  late ClassificationResult _classification;
  late ParsedTask? _parsedTask;
  
  // Task fields
  late TextEditingController _titleController;
  DateTime? _dueDate;
  int _priority = 1;
  String _domain = 'mind';
  
  // Expense fields
  late TextEditingController _amountController;
  String? _categoryId;
  DateTime? _expenseDate;
  
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final service = ref.read(inboxServiceProvider);
    _classification = service.classify(widget.capture);
    _selectedType = _classification.suggestedType;
    _parsedTask = _classification.parsedTask;
    
    _titleController = TextEditingController(
      text: _parsedTask?.title ?? widget.capture.content ?? '',
    );
    _dueDate = _parsedTask?.dueAt(DateTime.now());
    if (_parsedTask?.highPriority ?? false) _priority = 2;
    if (_parsedTask?.domain != null) _domain = _parsedTask!.domain!;
    
    _amountController = TextEditingController(
      text: _classification.suggestedAmount != null
          ? Money.formatPlain(_classification.suggestedAmount!)
          : '',
    );
    _expenseDate = DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final service = ref.read(inboxServiceProvider);
      
      switch (_selectedType) {
        case DestinationType.task:
          await service.createTask(
            widget.capture,
            title: _titleController.text,
            due: _dueDate,
            priority: _priority,
            domain: _domain,
          );
          
        case DestinationType.expense:
          final amount = Money.parseMinor(_amountController.text);
          if (amount == null || amount <= 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.mnAmountError)),
              );
              setState(() => _saving = false);
            }
            return;
          }
          await service.createExpense(
            widget.capture,
            amountMinor: amount,
            spentOn: _expenseDate,
            categoryId: _categoryId,
          );
          
        case DestinationType.document:
          // For document, we'll mark it and guide to capture flow
          await service.dismiss(widget.capture.id);
          
        case DestinationType.note:
          // Notes are just dismissed for now
          await service.dismiss(widget.capture.id);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getSuccessMessage())),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.inboxError)),
        );
      }
    }
  }

  String _getSuccessMessage() {
    final l = context.l10n;
    return switch (_selectedType) {
      DestinationType.task => l.inboxCreatedTask,
      DestinationType.expense => l.inboxCreatedExpense,
      DestinationType.document => l.inboxCreatedDocument,
      DestinationType.note => l.inboxCreatedNote,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: Tokens.spaceM,
          right: Tokens.spaceM,
          bottom: bottomInset + Tokens.spaceM,
          top: Tokens.spaceM,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.inboxClassify, style: theme.textTheme.titleLarge),
            SizedBox(height: Tokens.spaceS),
            
            // Preview of captured content
            Container(
              padding: EdgeInsets.all(Tokens.spaceS),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Tokens.radiusS),
              ),
              child: Text(
                widget.capture.displayText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            SizedBox(height: Tokens.spaceM),
            
            // Destination type selector
            Text(l.inboxClassifyAs, style: theme.textTheme.labelLarge),
            SizedBox(height: Tokens.spaceS),
            SegmentedButton<DestinationType>(
              segments: [
                ButtonSegment(
                  value: DestinationType.task,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(l.inboxTypeTask),
                ),
                ButtonSegment(
                  value: DestinationType.expense,
                  icon: const Icon(Icons.attach_money),
                  label: Text(l.inboxTypeExpense),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (selection) {
                setState(() => _selectedType = selection.first);
              },
            ),
            SizedBox(height: Tokens.spaceM),
            
            // Type-specific fields
            if (_selectedType == DestinationType.task) _buildTaskFields(),
            if (_selectedType == DestinationType.expense) _buildExpenseFields(),
            
            SizedBox(height: Tokens.spaceM),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel),
                ),
                SizedBox(width: Tokens.spaceS),
                FilledButton(
                  key: const ValueKey('classify-save'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Text(l.create),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskFields() {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('classify-task-title'),
          controller: _titleController,
          decoration: InputDecoration(
            labelText: l.tkTask,
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        SizedBox(height: Tokens.spaceM),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(l.tkDue),
          subtitle: Text(_dueDate != null 
              ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
              : l.tkNoDate),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dueDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) {
              setState(() => _dueDate = picked);
            }
          },
        ),
        SizedBox(height: Tokens.spaceS),
        Text(l.tkPriority, style: theme.textTheme.labelLarge),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(l.tkLow)),
            ButtonSegment(value: 1, label: Text(l.tkMedium)),
            ButtonSegment(value: 2, label: Text(l.tkHigh)),
          ],
          selected: {_priority},
          onSelectionChanged: (selection) {
            setState(() => _priority = selection.first);
          },
        ),
      ],
    );
  }

  Widget _buildExpenseFields() {
    final l = context.l10n;
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('classify-expense-amount'),
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l.amount,
            prefixText: Money.prefix,
            border: const OutlineInputBorder(),
          ),
        ),
        SizedBox(height: Tokens.spaceM),
        Text(l.mnCategory, style: theme.textTheme.labelLarge),
        SizedBox(height: Tokens.spaceS),
        Wrap(
          spacing: Tokens.spaceS,
          runSpacing: Tokens.spaceXs,
          children: [
            for (final c in categories)
              ChoiceChip(
                avatar: CircleAvatar(
                  radius: 5,
                  backgroundColor: categoryColor(context, colorSlotFor(c)),
                ),
                label: Text('${c.icon ?? ''} ${categoryName(c)}'.trim()),
                selected: _categoryId == c.id,
                onSelected: (on) =>
                    setState(() => _categoryId = on ? c.id : null),
              ),
          ],
        ),
        SizedBox(height: Tokens.spaceM),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(l.mnDate),
          subtitle: Text(_expenseDate != null
              ? '${_expenseDate!.day}/${_expenseDate!.month}/${_expenseDate!.year}'
              : l.today),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _expenseDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _expenseDate = picked);
            }
          },
        ),
      ],
    );
  }
}
