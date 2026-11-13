import React from "react";
import { Dashboard } from "../ui/CommunityLayout";
import { RoleBadge, gameMeta, useApi } from "./shared";

export const emptyDashboard = { stats: {}, leaderboard: [], active_members: [], news: [], events: [], gallery: [] };

export function HomePage({ user, setPage }) {
  const { data, loading, error } = useApi("/api/dashboard", emptyDashboard);
  return <Dashboard user={user} setPage={setPage} data={data} loading={loading} error={error} games={gameMeta} roleBadge={<RoleBadge user={user} />} />;
}
