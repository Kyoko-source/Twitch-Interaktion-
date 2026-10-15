import React, { useEffect, useState } from "react";
import { api } from "../api";

const format = (value) => Number(value).toLocaleString("de-DE");
export function WalletHistory({ user }) {
  const [data, setData] = useState(null), [error, setError] = useState("");
  useEffect(() => {
    let alive = true;
    setError("");
    api("/api/wallet/history").then((result) => { if (alive) setData(result); }).catch((err) => { if (alive) setError(err.message); });
    return () => { alive = false; };
  }, [user.username, user.chickens]);
  return <section className="panel walletHistory"><h2>Dein Chicken-Konto</h2>
    <p>Die Rangliste zählt erspielte Chickens. Dein verfügbarer Kontostand enthält auch Admin-Buchungen und berücksichtigt Einkäufe.</p>
    {error && <p role="status">{error}</p>}
    {data && <><div className="walletEquation"><span><b>{format(data.summary.earned)}</b> erspielt</span><span><b>{data.summary.adjustments >= 0 ? "+" : ""}{format(data.summary.adjustments)}</b> Admin-Buchungen</span><span><b>−{format(data.summary.spent)}</b> Einkäufe</span><strong>= {format(data.wallet.chickens)} verfügbar</strong></div>
      <h3>Letzte Buchungen</h3><ul className="walletTransactions">{data.transactions.map((entry) => <li key={entry.id}><div><strong>{entry.label}</strong><small>{new Date(entry.created * 1000).toLocaleString("de-DE")}{entry.score !== undefined ? ` · ${format(entry.score)} Punkte` : ""}</small></div><b className={entry.amount < 0 ? "isDebit" : "isCredit"}>{entry.amount > 0 ? "+" : ""}{format(entry.amount)}</b></li>)}</ul>
      {!data.transactions.length && <p>Noch keine Buchungen.</p>}</>}
  </section>;
}
