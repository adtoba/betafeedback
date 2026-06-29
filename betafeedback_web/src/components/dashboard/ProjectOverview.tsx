"use client";

import { useState } from "react";

import { hueFromString, initials } from "@/lib/project-utils";
import type { Member, Project } from "@/lib/types";

type ProjectOverviewProps = {
  project: Project;
  role: string | null;
  openBugs: number;
  onCopyInvite: () => void;
};

export function ProjectOverview({
  project,
  role,
  openBugs,
  onCopyInvite,
}: ProjectOverviewProps) {
  const [open, setOpen] = useState(false);

  const developers =
    project.members?.filter((m) => m.role === "developer" || m.role === "creator") ?? [];
  const buildLinks = project.platform_links ?? [];
  const hasDetails = developers.length > 0 || buildLinks.length > 0;

  return (
    <section className="dash-overview card">
      <div className="dash-overview__bar">
        <div className="dash-overview__left">
          <span
            className="dash-avatar dash-avatar--lg"
            style={{ "--hue": hueFromString(project.id) } as React.CSSProperties}
            aria-hidden="true"
          >
            {initials(project.name)}
          </span>
          <div className="dash-overview__id">
            <h1>
              {project.name}
              {role && <span className="dash-tag">{role}</span>}
            </h1>
            {project.description && (
              <p className="dash-overview__desc">{project.description}</p>
            )}
          </div>
        </div>

        <div className="dash-overview__right">
          <div className="dash-overview__stats">
            <span>
              <b>{project.tester_count}</b>testers
            </span>
            <span>
              <b>{project.member_count}</b>members
            </span>
            <span>
              <b>{openBugs}</b>open bugs
            </span>
          </div>
          <div className="dash-overview__actions">
            <button type="button" className="btn btn--ghost btn--sm" onClick={onCopyInvite}>
              Copy invite
            </button>
            <button
              type="button"
              className="dash-overview__toggle"
              onClick={() => setOpen((v) => !v)}
              aria-expanded={open}
            >
              Details
              <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.4"
                strokeLinecap="round"
                strokeLinejoin="round"
                className={open ? "dash-overview__chev dash-overview__chev--open" : "dash-overview__chev"}
                aria-hidden="true"
              >
                <path d="M6 9l6 6 6-6" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      {open && (
        <div className="dash-overview__details">
          <div>
            <p className="dash-field-label">Invite link</p>
            <div className="dash-overview__invite">
              <code>{project.invite_link}</code>
              <button type="button" className="btn btn--ghost btn--sm" onClick={onCopyInvite}>
                Copy
              </button>
            </div>
          </div>

          {buildLinks.length > 0 && (
            <div>
              <p className="dash-field-label">Builds</p>
              <ul className="dash-overview__links">
                {buildLinks.map((link) => (
                  <li key={link.platform}>
                    <span>{link.platform}</span>
                    <a href={link.url} target="_blank" rel="noreferrer">
                      Open build →
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {developers.length > 0 && (
            <div>
              <p className="dash-field-label">Team</p>
              <ul className="dash-overview__team">
                {developers.map((m: Member) => (
                  <li key={m.user_id}>
                    <span className="dash-member">
                      <span
                        className="dash-avatar"
                        style={{ "--hue": m.avatar_hue } as React.CSSProperties}
                        aria-hidden="true"
                      >
                        {initials(m.name)}
                      </span>
                      {m.name}
                      <span className="dash-member__role">{m.role}</span>
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {!hasDetails && (
            <p className="dash-muted">Share the invite link to add testers and developers.</p>
          )}
        </div>
      )}
    </section>
  );
}
