# Vault Features Guide

## 1. Upload / Import Documents from Images or Folder

### How to Access:
**Vault Home** → Top-right toolbar → **Upload icon** (📤) or button labeled **"Import from files"**

### What It Does:
- Opens a file picker to select images or PDFs from your device's Photos/Gallery or File Manager
- Each PDF becomes one document
- Multiple images become one document (converted to PDF)
- You can edit the title, type, and folder before saving

### Workflow:
1. **Vault** tab → **Upload** button (top right)
2. Select images (.jpg, .png, etc.) or PDF files
3. Review screen appears → edit title, document type, folder assignment
4. **Save to Vault** → Document is filed immediately

---

## 2. Delete Document (with Confirmation) ✅ **ADDED**

### Delete Locations:

#### Option A: From Document Viewer (top-right toolbar)
1. Open a document (tap on it in Vault)
2. Tap **Delete** button (trash icon) at bottom
3. **Confirmation dialog** appears: "Delete [Document Title]?"
4. Confirm to move to Trash (30-day recovery window)

#### Option B: From Edit Panel (side panel)
1. Open a document → Tap **Edit** button
2. Scroll down → **Delete** button (red text)
3. **Confirmation dialog** appears
4. Confirm to move to Trash

#### Option C: From Trash Screen
1. Vault → Trash icon (top right)
2. Find deleted document
3. **Delete forever** button (skips the 30-day wait)
4. Confirmation dialog appears

### Recovery:
- Deleted documents stay in **Trash** for 30 days
- Tap **Restore** to bring back to original folder
- After 30 days, automatically purged

---

## 3. Archive / Unarchive

Archived documents disappear from folder lists but stay searchable.

### Archive a Document:
1. Open document → Tap **Archive** button (archive icon)
2. Document disappears from Vault home & folders
3. Search still finds it

### Unarchive:
1. Search for document → Open it
2. Tap **Unarchive** button (appears instead of Archive)
3. Returns to its folder immediately

---

## Summary Table

| Feature | Location | Icon | Result |
|---------|----------|------|--------|
| **Import** | Vault home, top-right | 📤 | Opens file picker |
| **Delete** | Document viewer or edit panel | 🗑️ | Moves to Trash (asks first) |
| **Archive** | Document viewer | 📦 | Hides from lists, stays searchable |
| **Restore** | Trash screen | ↩️ | Returns to original folder |

---

## Code Changes

### Deletion Confirmation (Viewer)
- **File:** `lib/features/vault/document_viewer_screen.dart` (lines 127–146)
- **Change:** Added `showDialog` confirmation before calling `deleteDocument()`
- **Same pattern used in:** Edit panel (already had this)

### Existing Import Feature
- **Entry point:** `importFiles(context)` in `capture_entry.dart`
- **Calls:** `FileImporterProvider` (platform-specific: uses native file picker)
- **UI:** Review screen shows fields, folder picker, title editor
