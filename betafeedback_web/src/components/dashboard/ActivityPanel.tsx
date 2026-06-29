"use client";

import { hueFromString, initials, relativeTime } from "@/lib/project-utils";
import type { Activity } from "@/lib/types";

export function ActivityPanel({ items }: { items: Activity[] }) {
  if (items.length === 0) {
    return (
      <div className="dash-empty">
        <div className="dash-empty__icon" aria-hidden="true">
          ⚡
        </div>
        <h2>No activity yet</h2>
        <p>Bug fixes, releases, and updates will be logged here.</p>
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
                style={{ "--hue": hueFromString(item.actor_name) } as React.CSSProperties}
                aria-hidden="true"
              >
                {initials(item.actor_name)}
              </span>
              <span>
                <strong>{item.actor_name}</strong>{" "}
                {item.type === "bug_fixed" && "marked as fixed"}
                {item.type === "bug_structured" && "structured"}
                {item.type === "release_shipped" && "shipped"}{" "}
                <span>{item.subject}</span>
              </span>
            </span>
            <time className="dash-muted">{relativeTime(item.created_at)}</time>
          </div>
          {item.note && <p className="dash-muted">{item.note}</p>}
        </li>
      ))}
    </ul>
  );
}
