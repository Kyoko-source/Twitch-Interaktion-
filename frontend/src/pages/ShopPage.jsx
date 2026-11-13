import React from "react";
import { CommunityShop } from "../economy/CommunityShop";
import { useApi } from "./shared";

export function ShopPage({ user, setPage }) {
  const { data, error, loading } = useApi("/api/shop", []);
  return <CommunityShop user={user} setPage={setPage} data={data} error={error} loading={loading} />;
}
