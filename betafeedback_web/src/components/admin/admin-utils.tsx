"use client";

export function formatWhen(iso: string) {
  try {
    return new Intl.DateTimeFormat(undefined, {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(iso));
  } catch {
    return iso;
  }
}

export function formatShort(iso: string) {
  try {
    return new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(
      new Date(iso),
    );
  } catch {
    return iso;
  }
}

export function swapStatusBadge(status: string) {
  switch (status) {
    case "fulfilled":
    case "accepted":
      return "admin-badge admin-badge--ok";
    case "pending":
      return "admin-badge admin-badge--warn";
    case "declined":
    case "cancelled":
      return "admin-badge admin-badge--danger";
    default:
      return "admin-badge";
  }
}

type PagerProps = {
  total: number;
  limit: number;
  offset: number;
  onPrev: () => void;
  onNext: () => void;
};

export function AdminPager({ total, limit, offset, onPrev, onNext }: PagerProps) {
  const from = total === 0 ? 0 : offset + 1;
  const to = Math.min(offset + limit, total);
  return (
    <div className="admin-pager">
      <span>
        {from}–{to} of {total}
      </span>
      <div style={{ display: "flex", gap: 8 }}>
        <button
          type="button"
          className="admin-btn"
          disabled={offset <= 0}
          onClick={onPrev}
        >
          Previous
        </button>
        <button
          type="button"
          className="admin-btn"
          disabled={offset + limit >= total}
          onClick={onNext}
        >
          Next
        </button>
      </div>
    </div>
  );
}
