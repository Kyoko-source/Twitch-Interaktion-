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

export async function api(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await fetch(`${API_BASE}${path}`, { ...options, headers });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(data?.detail || "Anfrage fehlgeschlagen");
  }
  return data;
}
