"use client";

import { useState } from "react";

import { apiRequest } from "@/lib/api-client";
import type { Release } from "@/lib/types";

type FixBugDialogProps = {
  projectId: string;
  bugId: string;
  bugTitle: string;
  releases: Release[];
  token: string;
  open: boolean;
  onClose: () => void;
  onFixed: () => void;
};

export function FixBugDialog({
  projectId,
  bugId,
  bugTitle,
  releases,
  token,
  open,
  onClose,
  onFixed,
}: FixBugDialogProps) {
  const [note, setNote] = useState("");
  const [releaseId, setReleaseId] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!open) return null;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      await apiRequest(`/v1/projects/${projectId}/bugs/${bugId}/fix`, {
        method: "POST",
        token,
        body: {
          ...(note.trim() ? { note: note.trim() } : {}),
          ...(releaseId ? { release_id: releaseId } : {}),
        },
      });
      setNote("");
      setReleaseId("");
      onFixed();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not mark fixed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="dash-modal-backdrop" onClick={onClose} role="presentation">
      <div className="dash-modal" onClick={(e) => e.stopPropagation()} role="dialog">
        <h2>Mark as fixed</h2>
        {bugTitle && <p className="dash-modal__sub">{bugTitle}</p>}
        <form onSubmit={submit} className="dash-form">
          <textarea
            className="dash-input dash-input--area"
            rows={3}
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="Fix note (optional)"
          />
          {releases.length > 0 && (
            <select
              className="dash-input"
              value={releaseId}
              onChange={(e) => setReleaseId(e.target.value)}
            >
              <option value="">Release (optional)</option>
              {releases.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.version}
                </option>
              ))}
            </select>
          )}
          {error && <p className="dash-error">{error}</p>}
          <div className="dash-detail__actions">
            <button type="button" className="btn btn--ghost btn--sm" onClick={onClose}>
              Cancel
            </button>
            <button type="submit" className="btn btn--primary btn--sm" disabled={loading}>
              {loading ? "…" : "Mark fixed"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
