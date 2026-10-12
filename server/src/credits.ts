import { DatabaseSync } from 'node:sqlite';

export interface LedgerEntry {
  delta: number;
  reason: string;
  provider?: string;
  model?: string;
  inputTokens?: number;
  outputTokens?: number;
}

/**
 * Credit balances and an append-only ledger (SQLite, built into Node).
 * Balances never go below zero; every change is a ledger row.
 */
export class CreditStore {
  private readonly db: DatabaseSync;
  private readonly freeCredits: number;

  constructor(path: string, freeCredits: number) {
    this.db = new DatabaseSync(path);
    this.freeCredits = freeCredits;
    this.db.exec(`
      PRAGMA journal_mode = WAL;
      CREATE TABLE IF NOT EXISTS users (
        uid TEXT PRIMARY KEY,
        credits INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
      CREATE TABLE IF NOT EXISTS ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL REFERENCES users(uid),
        delta INTEGER NOT NULL,
        reason TEXT NOT NULL,
        provider TEXT,
        model TEXT,
        input_tokens INTEGER,
        output_tokens INTEGER,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
      CREATE INDEX IF NOT EXISTS ledger_uid ON ledger(uid, created_at);
    `);
  }

  /** Creates the account on first sight with the free starter credits. */
  ensureUser(uid: string): number {
    const row = this.db.prepare('SELECT credits FROM users WHERE uid = ?').get(uid) as
      | { credits: number }
      | undefined;
    if (row) return row.credits;
    this.db.exec('BEGIN');
    try {
      this.db.prepare('INSERT INTO users (uid, credits) VALUES (?, ?)').run(uid, this.freeCredits);
      this.db
        .prepare('INSERT INTO ledger (uid, delta, reason) VALUES (?, ?, ?)')
        .run(uid, this.freeCredits, 'signup_bonus');
      this.db.exec('COMMIT');
    } catch (e) {
      this.db.exec('ROLLBACK');
      throw e;
    }
    return this.freeCredits;
  }

  balance(uid: string): number {
    return this.ensureUser(uid);
  }

  /** Applies a change atomically; negative deltas are clamped at zero. */
  apply(uid: string, entry: LedgerEntry): number {
    this.ensureUser(uid);
    this.db.exec('BEGIN');
    try {
      const { credits } = this.db.prepare('SELECT credits FROM users WHERE uid = ?').get(uid) as {
        credits: number;
      };
      const next = Math.max(0, credits + entry.delta);
      this.db.prepare('UPDATE users SET credits = ? WHERE uid = ?').run(next, uid);
      this.db
        .prepare(
          `INSERT INTO ledger (uid, delta, reason, provider, model, input_tokens, output_tokens)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
        )
        .run(
          uid,
          next - credits,
          entry.reason,
          entry.provider ?? null,
          entry.model ?? null,
          entry.inputTokens ?? null,
          entry.outputTokens ?? null,
        );
      this.db.exec('COMMIT');
      return next;
    } catch (e) {
      this.db.exec('ROLLBACK');
      throw e;
    }
  }

  history(uid: string, limit = 50): unknown[] {
    return this.db
      .prepare('SELECT delta, reason, model, input_tokens, output_tokens, created_at FROM ledger WHERE uid = ? ORDER BY id DESC LIMIT ?')
      .all(uid, limit);
  }

  close(): void {
    this.db.close();
  }
}
