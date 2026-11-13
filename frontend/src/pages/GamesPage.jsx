import React, { Suspense, useEffect, useState, lazy } from "react";
import { Gamepad2, Zap } from "lucide-react";
import { GameScoreboard } from "../economy/GameScoreboard";
import { PepplePinball } from "../pinball/PepplePinball";
import { ChickenJump } from "../jump/ChickenJump";
import { ChickenSnake } from "../snake/ChickenSnake";
import { gameMeta, routeParts } from "./shared";
const PeppleSurvivor = lazy(() => import("../survivor/PeppleSurvivor").then((module) => ({ default: module.PeppleSurvivor })));
const DungeonsAndDragons = lazy(() => import("../dnd/DndTable").then((module) => ({ default: module.DungeonsAndDragons })));
const Nullsignal = lazy(() => import("../nullsignal/Nullsignal").then((module) => ({ default: module.Nullsignal })));
const AfterPlay = lazy(() => import("../nachtwache/Nachtwache").then((module) => ({ default: module.AfterPlay })));

export const Scoreboard = GameScoreboard;

export function GamesPage({ user }) {
  const gameFromRoute = () => {
    const [, nextGame] = routeParts();
    if (nextGame === "chicken-racer") return "chicken-flipper";
    if (nextGame === "nachtwache") return "after-play";
    return gameMeta[nextGame] ? nextGame : "chicken-jump";
  };
  const [game, setGameState] = useState(gameFromRoute);
  function setGame(nextGame) {
    setGameState(nextGame);
    window.history.replaceState(null, "", `/#games/${nextGame}`);
  }
  useEffect(() => {
    function syncGame() { setGameState(gameFromRoute()); }
    window.addEventListener("hashchange", syncGame);
    window.addEventListener("popstate", syncGame);
    return () => {
      window.removeEventListener("hashchange", syncGame);
      window.removeEventListener("popstate", syncGame);
    };
  }, []);
  const current = {
    "chicken-jump": <ChickenJump user={user} renderScoreboard={(refreshKey) => <Scoreboard game="chicken-jump" refreshKey={refreshKey} />} />,
    "chicken-snake": <ChickenSnake user={user} renderScoreboard={(refreshKey) => <Scoreboard game="chicken-snake" refreshKey={refreshKey} />} />,
    "chicken-flipper": <PepplePinball user={user} renderScoreboard={(refreshKey) => <Scoreboard game="chicken-flipper" refreshKey={refreshKey} />} />,
    "braincell-survivor": <Suspense fallback={<div className="notice">Lade Pepple Survivor …</div>}><PeppleSurvivor user={user} renderScoreboard={(refreshKey) => <Scoreboard game="braincell-survivor" refreshKey={refreshKey} />} /></Suspense>,
    dnd: <Suspense fallback={<div className="notice">Der Spieltisch wird aufgebaut …</div>}><DungeonsAndDragons user={user} onLogin={() => { window.location.hash = "login"; }} /></Suspense>,
    "nullsignal": <Suspense fallback={<div className="notice">NULLSIGNAL wird vorbereitet …</div>}><Nullsignal user={user}/></Suspense>,
    "after-play": <Suspense fallback={<div className="notice">After Play wird vorbereitet …</div>}><AfterPlay/></Suspense>,
  }[game];

  return (
    <section className="gamesShell">
      <div className="sectionHero arcadeHero">
        <div>
          <p className="kicker">Minispiele</p>
          <h1>Dein nächster Highscore wartet.</h1>
          <p>Neue Bestleistungen, gemeinsame Abenteuer und eine unheimliche Nachtschicht. Such dir dein Spiel aus.</p>
        </div>
        <Zap size={64} />
      </div>
      {game !== "dnd" && game !== "nullsignal" && game !== "after-play" && <div className="gameEarningInfo">Chickens verdienen: Runde spielen und danach den Score einreichen. Bis zu 25 pro Runde und 120 pro Tag, ab 15 Sekunden Spielzeit. Punkte und Spielzeit bestimmen deine Belohnung.</div>}
      <div className="gameTabs">
        {Object.entries(gameMeta).map(([id, meta]) => (
          <button className={game === id ? "active" : ""} key={id} onClick={() => setGame(id)} type="button">
            <Gamepad2 size={16} /> {meta.title}
          </button>
        ))}
      </div>
      {current}
    </section>
  );
}
