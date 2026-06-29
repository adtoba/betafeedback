"use client";

import { hueFromString, initials, relativeTime } from "@/lib/project-utils";
import type { Feedback } from "@/lib/types";

export function FeedbackPanel({ items }: { items: Feedback[] }) {
  if (items.length === 0) {
    return (
      <div className="dash-empty">
        <div className="dash-empty__icon" aria-hidden="true">
          💬
        </div>
        <h2>No feedback yet</h2>
        <p>Testers&apos; notes and suggestions will show up here.</p>
      </div>
    );
  }

  return (
    <ul className="dash-panel-list">
      {items.map((item) => (
        <li key={item.id} className="dash-panel-list__item">
          <div className="dash-panel-list__head">
            <span className="dash-member">
              <span
                className="dash-avatar"
                style={{ "--hue": hueFromString(item.author_name) } as React.CSSProperties}
                aria-hidden="true"
              >
                {initials(item.author_name)}
              </span>
              <strong>{item.author_name}</strong>
            </span>
            <time className="dash-muted">{relativeTime(item.created_at)}</time>
          </div>
          {item.title && <h3 className="dash-panel-list__title">{item.title}</h3>}
          <p>{item.body}</p>
          {(item.platform || item.device) && (
            <p className="dash-muted">
              {[item.platform, item.device].filter(Boolean).join(" · ")}
            </p>
          )}
        </li>
      ))}
    </ul>
  );
}
