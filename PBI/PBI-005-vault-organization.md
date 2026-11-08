# PBI-005 — Vault Home: Folders, People, Tags, Favourites

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §1.3; UI flow §3.1, §3.2 |
| Depends on | PBI-002 |
| Status | Ready |

## User Story
As a **user**, I want my documents organised by folder and by family member so I can find them at a glance.

## Description
- Vault Home: search bar, People chips (Me / Spouse / Child / Parent / +), Expiring Soon strip (data from PBI-008), folder list with document counts, persistent 📸 Scan button
- People profiles: create, edit and delete (soft delete), with name, relation and emoji avatar
- Custom folders: create, rename, choose an icon, soft delete. System folders can't be deleted.
- Folder view and Person view: document list with thumbnail, title, type chip and date
- Tags: several free-text tags per document
- Favourite/pin: pinned documents appear at the top of every list

## Acceptance Criteria
1. Every document belongs to at most one person and one folder, and can have any number of tags.
2. Folder counts update immediately after a document is saved, moved or deleted.
3. Adding a person makes it appear in the People strip, and its view lists only that person's documents.
4. A system folder shows no delete option. Deleting a custom folder moves its documents to "Unfiled" (no data loss).
5. Each empty folder or person view shows an illustrated empty state with a "Scan" action.
6. Nothing in the Vault is more than 2 taps from the bottom bar.
