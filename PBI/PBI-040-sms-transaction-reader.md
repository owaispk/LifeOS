# PBI-040 — SMS Transaction Reader: Auto-Log Expenses from Bank SMS

| Field | Value |
|---|---|
| Epic | E4 Money |
| Priority | P1 |
| Story Points | 8 |
| Spec refs | Features §4.1 (Expense Log), §4.5 (SMS Integration) |
| Depends on | PBI-002, PBI-018 |
| Status | In Progress |

## User Story
As a **user**, I want LifeOS to read my bank SMS notifications and automatically log transactions as expenses, so I can track my spending without manual entry.

## Description
- **Android only**: Read SMS messages with READ_SMS permission (iOS does not allow third-party SMS access)
- **Bank SMS detection**: Identify transaction SMS from Pakistani banks (HBL, UBL, MCB, Meezan, JazzCash, Easypaisa, etc.)
- **Transaction parsing**: Extract amount, merchant/description, date, transaction type (debit/credit), and account info
- **Auto-expense logging**: Optionally create expenses in Money from detected debits
- **Transaction history**: View all parsed SMS transactions in a dedicated screen
- **Privacy-first**: SMS reading is opt-in, data stays on-device, no cloud sync of SMS content

## Acceptance Criteria
1. Toggling "Read bank SMS" ON requests READ_SMS permission; denying it shows an explanation and keeps the toggle OFF.
2. A debit SMS "Rs. 5,000 debited from A/C ***1234 at SHELL PUMP" parses to amount=500000 (minor units), merchant="SHELL PUMP", type=debit.
3. Credit SMS (salary, transfers in) are parsed but NOT auto-logged as expenses.
4. Duplicate SMS (same amount, same time, same account) are detected and not double-logged.
5. The transaction list shows all parsed SMS grouped by date, with amount, merchant, and "Logged ✓" or "Log as expense" action.
6. Manually logging an SMS transaction links it to the expense (like payment-linked expenses).
7. Auto-log mode (optional) creates expenses immediately for all debits, with a daily summary notification.
8. The SMS parser handles multiple bank formats (tested with 5+ Pakistani banks).
9. iOS shows "SMS reading is not available on iPhone" with alternative suggestions.

## Grooming Clarifications

### Permission & Privacy
- **Opt-in only**: Settings → Money → "Read bank SMS" toggle, OFF by default
- **Permission request**: Standard Android READ_SMS runtime permission
- **On-device only**: SMS content is parsed locally; only extracted transaction data is stored in the database
- **No raw SMS storage**: We store parsed transactions, not the original SMS text

### SMS Parsing Strategy
- **Sender filtering**: Only read SMS from known bank sender IDs (e.g., "HBL", "UBL-Alert", "JazzCash", "Easypaisa")
- **Pattern matching**: Regex patterns for Pakistani bank SMS formats:
  ```
  Debit patterns:
  - "Rs. {amount} debited from A/C {account} at {merchant}"
  - "PKR {amount} withdrawn from {account}"
  - "{amount} spent at {merchant} on card {card}"
  - "Payment of Rs.{amount} to {merchant}"
  
  Credit patterns:
  - "Rs. {amount} credited to A/C {account}"
  - "Received PKR {amount} from {sender}"
  - "Salary credited: Rs. {amount}"
  ```
- **Amount parsing**: Handle "Rs.", "PKR", commas, decimals → convert to minor units
- **Date extraction**: Use SMS timestamp, or parse date from SMS body if present

### Database Schema (schema v7)
```sql
CREATE TABLE sms_transactions (
  id TEXT PRIMARY KEY,
  sms_sender TEXT NOT NULL,        -- e.g., "HBL", "JazzCash"
  sms_hash TEXT NOT NULL UNIQUE,   -- SHA256 of sender+timestamp+amount for dedup
  amount_minor INTEGER NOT NULL,
  transaction_type TEXT NOT NULL,  -- 'debit' | 'credit'
  merchant TEXT,                   -- extracted merchant/description
  account_masked TEXT,             -- e.g., "***1234"
  card_masked TEXT,                -- e.g., "****5678" if card transaction
  sms_timestamp TEXT NOT NULL,     -- ISO8601, when SMS was received
  parsed_at TEXT NOT NULL,         -- when we parsed it
  expense_id TEXT,                 -- linked expense if logged
  auto_logged INTEGER DEFAULT 0,   -- 1 if auto-logged
  ignored INTEGER DEFAULT 0,       -- 1 if user dismissed
  FOREIGN KEY (expense_id) REFERENCES expenses(id)
);

CREATE INDEX idx_sms_transactions_timestamp ON sms_transactions(sms_timestamp DESC);
CREATE INDEX idx_sms_transactions_expense ON sms_transactions(expense_id);
```

### UI Screens
1. **Settings toggle**: Settings → Money → "Read bank SMS" with explanation text
2. **Transaction list**: Money → "SMS Transactions" tab or button
   - Grouped by date
   - Each row: Bank icon, amount (green credit / red debit), merchant, time
   - Swipe or tap to "Log as expense" (opens expense sheet pre-filled)
   - "Auto-log all debits" toggle at top
3. **Logged indicator**: Transactions linked to expenses show "✓ Logged" badge
4. **iOS fallback screen**: Explains iOS limitation, suggests:
   - Forward bank SMS to email
   - Manual expense entry
   - Copy-paste SMS for parsing

### Auto-Log Mode
- When enabled, every new debit SMS automatically creates an expense
- Category is guessed from merchant name (SHELL → transport, METRO → groceries)
- Daily summary notification at 21:00: "Today: 5 transactions, Rs. 12,500 spent"
- User can review and edit auto-logged expenses in Money

### Bank Sender IDs (Pakistan)
| Bank | Sender IDs |
|------|-----------|
| HBL | HBL, HBL-Alert, HBLKonnect |
| UBL | UBL, UBL-Alert |
| MCB | MCB, MCB-Alert |
| Meezan | Meezan, MBL |
| Allied | ABL, ABL-Alert |
| Askari | AKBL |
| Bank Alfalah | Alfalah, BAF |
| Faysal | FBL |
| JazzCash | JazzCash, Jazz |
| Easypaisa | Easypaisa, EP |
| SadaPay | SadaPay |
| NayaPay | NayaPay |

### Flutter Implementation
- **Package**: `flutter_sms_inbox` or `telephony` for reading SMS on Android
- **Background sync**: Check SMS on app start and resume (like ATC generator)
- **Service**: `SmsTransactionService` in `lib/features/money/data/`
- **Parser**: `BankSmsParser` in `lib/features/money/domain/` (pure Dart, testable)
- **Provider**: `smsTransactionsProvider` streams parsed transactions

### Edge Cases
- **OTP/verification SMS**: Filtered out (contain "OTP", "verification", "code")
- **Promotional SMS**: Filtered out (no transaction pattern match)
- **International transactions**: Parse USD/AED/GBP amounts, store in original currency
- **Failed transactions**: Detect "failed", "declined", "unsuccessful" — don't log
- **Reversed transactions**: If a reversal SMS arrives, mark original as reversed

## Implementation Notes

### Phase 1: Core SMS Reading
1. Add `READ_SMS` permission to AndroidManifest.xml
2. Add `telephony` or `flutter_sms_inbox` package
3. Create `BankSmsParser` with regex patterns for 5 major banks
4. Create `sms_transactions` table (schema v7)
5. Create `SmsTransactionService` for reading and parsing
6. Add Settings toggle with permission request flow

### Phase 2: UI & Logging
1. SMS Transactions list screen
2. "Log as expense" action with pre-filled expense sheet
3. Link `sms_transaction.expense_id` when logged
4. Show logged indicator

### Phase 3: Auto-Log & Intelligence
1. Auto-log toggle and background processing
2. Category guessing from merchant names
3. Daily summary notification
4. Duplicate and reversal detection

## Test Plan
- Unit tests for `BankSmsParser` with 50+ real SMS samples
- Service tests for dedup logic
- Widget tests for permission flow and transaction list
- Integration test: mock SMS → parsed transaction → logged expense

---

## What Happens After Reading SMS

### Flow Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Bank SMS      │────▶│  SMS Transaction │────▶│    Expense      │
│   Received      │     │  (parsed & stored)│     │   (auto/manual) │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                │
                                ▼
                        ┌──────────────────┐
                        │  Match to ATC    │ (optional)
                        │  Payment Task?   │
                        └──────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
            ┌──────────────┐        ┌──────────────┐
            │ YES: Auto-   │        │ NO: Create   │
            │ complete the │        │ standalone   │
            │ payment task │        │ expense only │
            └──────────────┘        └──────────────┘
```

### Scenario 1: SMS Matches an ATC Payment Task

**Example:** You have a rent rule (Rs 45,000, due 1st of each month). On Dec 1st, you pay and receive:
> "Rs. 45,000 debited from A/C ***1234 for LANDLORD TRANSFER"

**What happens:**

| Step | Action | Result |
|------|--------|--------|
| 1 | SMS parsed | `sms_transaction` created: amount=4500000, merchant="LANDLORD TRANSFER" |
| 2 | Match detected | Amount + date matches pending "Rent — Rs 45,000" task |
| 3 | User confirms | Notification: "Rent payment detected. Mark as paid?" |
| 4 | Completion chain | Task ✓ done, Payment → paid, Expense logged, Score updated |
| 5 | SMS linked | `sms_transaction.expense_id` → the created expense |

**Benefits:**
- No manual task completion needed
- Receipt can still be attached later
- Payment history shows SMS as source

### Scenario 2: SMS Does NOT Match Any Task (Standalone Expense)

**Example:** You buy groceries and receive:
> "Rs. 2,500 spent at METRO CASH&CARRY on card ****5678"

**What happens:**

| Step | Action | Result |
|------|--------|--------|
| 1 | SMS parsed | `sms_transaction` created: amount=250000, merchant="METRO CASH&CARRY" |
| 2 | No match | No pending payment task matches this amount/merchant |
| 3a | **If Auto-log ON** | Expense created automatically, category guessed (groceries) |
| 3b | **If Auto-log OFF** | Transaction saved, shown in "SMS Transactions" list for manual review |
| 4 | User action | Can tap "Log as expense" or ignore |

### Scenario 3: Credit SMS (Salary, Transfer In)

**Example:**
> "Rs. 150,000 credited to A/C ***1234 — SALARY OCT 2026"

**What happens:**
- Parsed and stored as `transaction_type = 'credit'`
- **NOT logged as expense** (credits aren't spending)
- Shown in SMS Transactions list with green amount
- Future: Could be used for income tracking (separate PBI)

---

## Integration with Existing Features

### Tasks (PBI-009, PBI-013)

| Feature | Integration |
|---------|-------------|
| **ATC Payment Tasks** | SMS can auto-complete matching payment tasks |
| **Task matching** | Match by: amount ± 5%, due date ± 3 days, or merchant keyword |
| **Notification** | "Rent payment detected — Mark task as paid?" with [Yes] [No] |
| **Manual override** | User can always complete tasks manually (existing flow) |

### Expenses (PBI-018)

| Feature | Integration |
|---------|-------------|
| **Auto-log** | Creates expense with `sms_transaction_id` link |
| **Category** | Guessed from merchant OR inherited from matched ATC rule |
| **Amount** | Exact amount from SMS (no manual entry errors) |
| **Date** | SMS timestamp as `spent_on` |
| **Edit/Delete** | SMS-linked expenses can be edited but not deleted (like payment-linked) |

### Money Overview (PBI-018)

| Feature | Integration |
|---------|-------------|
| **Month total** | Includes all SMS-logged expenses |
| **Category breakdown** | SMS expenses grouped by category |
| **Recent list** | Shows 📱 icon for SMS-sourced expenses |
| **Source indicator** | "Logged from SMS" label (like "Logged from payment") |

### Completion Chain (PBI-016)

When SMS matches a payment task and user confirms:

```dart
// Same completion chain, with SMS as trigger
markPaid(
  paymentId: matchedPayment.id,
  source: PaymentSource.sms,  // NEW: track that SMS triggered it
  smsTransactionId: smsTransaction.id,
  // No receipt from SMS — user can add later
);
```

The chain runs exactly as before:
1. Payment → `paid`
2. Task → done
3. Expense created (linked to both payment AND sms_transaction)
4. Life Score updated
5. Confirmations: "Paid via SMS · Logged in Money · Score +N"

---

## Settings & Controls

### Settings → Money → SMS Transactions

| Setting | Default | Description |
|---------|---------|-------------|
| **Read bank SMS** | OFF | Master toggle, requests READ_SMS permission |
| **Auto-log expenses** | OFF | Automatically create expenses from debits |
| **Auto-complete tasks** | ON | Auto-match SMS to pending payment tasks |
| **Daily summary** | ON | 9 PM notification with day's transactions |

### User Controls

| Action | Where | Result |
|--------|-------|--------|
| **Log as expense** | SMS Transactions list | Opens expense sheet pre-filled |
| **Mark as paid** | Notification / SMS list | Completes matched payment task |
| **Ignore** | Swipe left on SMS | Marks `ignored = 1`, won't prompt again |
| **Undo auto-log** | Expense detail | Deletes expense, keeps SMS transaction |

---

## Implementation Progress (2026-11-13)

### Phase 1: Core SMS Reading ✅
- [x] `BankSmsParser` — pure Dart parsing logic with regex patterns
- [x] `sms_transactions` table — schema v17 with dedup hash
- [x] `SmsTransactionService` — CRUD + expense linking
- [x] `SmsReader` — platform channel for Android
- [x] Android native code in `MainActivity.kt`
- [x] `READ_SMS` permission in AndroidManifest.xml
- [x] SMS settings columns in `UserSettings`
- [x] Riverpod providers for SMS transactions
- [x] Localization strings (English + Urdu)
- [x] Unit tests for `BankSmsParser`

### Phase 2: UI & Logging ✅
- [x] `SmsTransactionsScreen` — list with date grouping
- [x] "Log as expense" action with prefilled sheet
- [x] Updated `ExpenseSheet` to accept prefill values
- [x] Logged indicator in transaction rows
- [x] iOS unavailable screen

### Phase 3: Auto-Log & Intelligence (Pending)
- [ ] Auto-log toggle implementation
- [ ] Background sync on app start/resume
- [ ] Category guessing integration
- [ ] Daily summary notification
- [ ] Payment task matching and auto-complete
- [ ] Settings UI in Money settings

### Files Created/Modified:
```
lib/features/money/domain/bank_sms_parser.dart      # NEW - SMS parsing
lib/features/money/data/sms_transaction_service.dart # NEW - Service
lib/features/money/data/sms_reader.dart              # NEW - Platform channel
lib/features/money/ui/sms_transactions_screen.dart   # NEW - UI
lib/features/money/ui/expense_sheet.dart             # MODIFIED - prefill support
lib/features/money/money_providers.dart              # MODIFIED - SMS providers
lib/data/db/tables.dart                              # MODIFIED - SMS table
lib/data/db/app_database.dart                        # MODIFIED - schema v17
lib/data/repositories/repositories.dart              # MODIFIED - SMS repo
lib/l10n/app_en.arb                                  # MODIFIED - strings
lib/l10n/app_ur.arb                                  # MODIFIED - Urdu strings
android/.../AndroidManifest.xml                      # MODIFIED - permission
android/.../MainActivity.kt                          # MODIFIED - platform code
test/.../bank_sms_parser_test.dart                   # NEW - tests
```

---

## Not In Scope (Future)
- iOS SMS (platform limitation)
- Cloud sync of transactions (privacy)
- Multi-currency conversion
- Bank account aggregation APIs
- Receipt matching (PBI-003 handles receipts)
- Income tracking from credit SMS
