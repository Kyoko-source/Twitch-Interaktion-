import { useCallback, useRef, useState } from "react";
import { api } from "../api";

export function publishWallet(username, wallet) {
  if (wallet) window.dispatchEvent(new CustomEvent("aviary-wallet", { detail: { username, wallet } }));
}

export function requestId() {
  // getRandomValues also works on the existing HTTP deployment.
  return Array.from(crypto.getRandomValues(new Uint8Array(20)), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function useGameRewards(game, user) {
  const userRef = useRef(user);
  userRef.current = user;
  const activeRound = useRef(null);
  const pending = useRef(null);
  const [submitted, setSubmitted] = useState(false);
  const [saving, setSaving] = useState(false);

  const beginRound = useCallback(() => {
    setSubmitted(false);
    pending.current = null;
    activeRound.current = userRef.current ? api("/api/game-runs", { method: "POST", body: JSON.stringify({ game }) }).catch(() => null) : null;
  }, [game]);

  const submitRound = useCallback((score) => {
    if (pending.current) return pending.current;
    const username = userRef.current?.username;
    setSaving(true);
    const operation = (async () => {
      const round = await activeRound.current;
      if (!round?.run_id) throw new Error("Diese Runde konnte nicht registriert werden. Bitte starte eine neue Runde, während du angemeldet bist.");
      const result = await api("/api/scores", { method: "POST", body: JSON.stringify({ ...score, game, run_id: round.run_id }) });
      window.dispatchEvent(new CustomEvent("aviary-score-saved", { detail: { ...score, game, username, created_at: new Date().toISOString() } }));
      publishWallet(username, result.wallet);
      setSubmitted(true);
      return result;
    })();
    pending.current = operation;
    operation.catch(() => { if (pending.current === operation) pending.current = null; }).finally(() => setSaving(false));
    return operation;
  }, [game]);
  return { beginRound, submitRound, submitted, saving };
}
