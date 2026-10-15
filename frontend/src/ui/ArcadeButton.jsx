import React, { useRef } from "react";

// A touch action also works immediately after a captured game swipe. The
// synthetic click is consumed once; mouse and keyboard activation stay native.
export function ArcadeButton({ onClick, disabled, ...props }) {
  const touchHandled = useRef(false);
  return <button {...props} disabled={disabled} onPointerDown={() => { touchHandled.current = false; }} onPointerUp={(event) => {
    if (disabled || event.pointerType !== "touch") return;
    const bounds = event.currentTarget.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) return;
    event.preventDefault(); touchHandled.current = true; onClick?.(event);
  }} onClick={(event) => {
    if (touchHandled.current && event.detail !== 0) { touchHandled.current = false; return; }
    touchHandled.current = false; onClick?.(event);
  }} />;
}
