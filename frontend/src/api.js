const API_BASE = import.meta.env.VITE_API_BASE || "";

let token = localStorage.getItem("aviary_token") || "";

export function getToken() {
  return token;
}

export function setToken(value) {
  token = value || "";
  if (token) localStorage.setItem("aviary_token", token);
  else localStorage.removeItem("aviary_token");
}

export async function api(path, options = {}, responseType = "json") {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${API_BASE}${path}`, { ...options, headers });
  if (response.ok && responseType === "blob") return response.blob();
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const detail = data?.detail;
    const message = typeof detail === "string" ? detail : detail?.message || "Anfrage fehlgeschlagen";
    if (token && path !== "/api/auth/login" && (response.status === 401 || detail?.code === "account_banned")) {
      setToken("");
      window.dispatchEvent(new CustomEvent("aviary-session-ended", { detail: { message } }));
    }
    throw new Error(message);
  }
  return data;
}
