import React from 'react';
import {AbsoluteFill, Img, staticFile} from 'remotion';
import {numberFont, textFont} from '../shared/theme';

// App Store product page header (spec §10 Store listing): one universal creative asset,
// 5244×2950 PNG. Key art stays inside Apple's art safe area (1402×962 at x 1921, y 660);
// the rest is mood that some devices crop. No words, so English and Malay share it.
export const HEADER_WIDTH = 5244;
export const HEADER_HEIGHT = 2950;
const SAFE = {x: 1921, y: 660, w: 1402, h: 962};
const CX = SAFE.x + SAFE.w / 2;

/** Small deterministic random, so every render is the same. */
const seeded = (seed: number) => () => {
	seed = (seed * 1664525 + 1013904223) % 4294967296;
	return seed / 4294967296;
};

const Background: React.FC = () => {
	const rnd = seeded(408);
	const dots = Array.from({length: 140}, () => ({
		x: rnd() * HEADER_WIDTH,
		y: rnd() * 1500,
		r: 3 + rnd() * 9,
		o: 0.15 + rnd() * 0.45,
		hue: rnd() < 0.7 ? '127,190,255' : rnd() < 0.5 ? '255,190,110' : '160,130,255',
	}));
	const horizon = 1820;
	const vanishY = 1500;
	const lines: React.ReactNode[] = [];
	for (let i = -26; i <= 26; i++) {
		const xBottom = CX + i * 330;
		const t = (horizon - vanishY) / (HEADER_HEIGHT - vanishY);
		const xTop = CX + (xBottom - CX) * t;
		lines.push(<line key={`v${i}`} x1={xTop} y1={horizon} x2={xBottom} y2={HEADER_HEIGHT} />);
	}
	for (let k = 1; k <= 14; k++) {
		const y = horizon + (HEADER_HEIGHT - horizon) * Math.pow(k / 14, 2.1);
		lines.push(<line key={`h${k}`} x1={0} y1={y} x2={HEADER_WIDTH} y2={y} />);
	}
	return (
		<AbsoluteFill style={{background: '#04060C'}}>
			<AbsoluteFill
				style={{
					background:
						'radial-gradient(ellipse 2300px 1300px at 50% 39%, rgba(31,79,216,0.62) 0%, rgba(31,79,216,0.18) 45%, rgba(4,6,12,0) 75%),' +
						'radial-gradient(ellipse 1400px 500px at 22% 70%, rgba(120,70,255,0.22) 0%, rgba(4,6,12,0) 70%),' +
						'radial-gradient(ellipse 1400px 500px at 78% 70%, rgba(0,200,255,0.18) 0%, rgba(4,6,12,0) 70%)',
				}}
			/>
			<svg width={HEADER_WIDTH} height={HEADER_HEIGHT} style={{position: 'absolute', inset: 0}}>
				<defs>
					<linearGradient id="floor" x1="0" y1="0" x2="0" y2="1">
						<stop offset="0" stopColor="#4F8BFF" stopOpacity="0.05" />
						<stop offset="0.35" stopColor="#4F8BFF" stopOpacity="0.45" />
						<stop offset="1" stopColor="#7FD4FF" stopOpacity="0.6" />
					</linearGradient>
					<linearGradient id="horizonGlow" x1="0" y1="0" x2="1" y2="0">
						<stop offset="0" stopColor="#7FD4FF" stopOpacity="0" />
						<stop offset="0.5" stopColor="#9FE2FF" stopOpacity="0.95" />
						<stop offset="1" stopColor="#7FD4FF" stopOpacity="0" />
					</linearGradient>
					<radialGradient id="dot">
						<stop offset="0" stopColor="#fff" stopOpacity="1" />
						<stop offset="1" stopColor="#fff" stopOpacity="0" />
					</radialGradient>
				</defs>
				{dots.map((d, i) => (
					<circle key={i} cx={d.x} cy={d.y} r={d.r * 3} fill={`rgba(${d.hue},${d.o})`} style={{filter: 'blur(6px)'}} />
				))}
				<g stroke="url(#floor)" strokeWidth={4}>{lines}</g>
				<rect x={0} y={horizon - 3} width={HEADER_WIDTH} height={6} fill="url(#horizonGlow)" />
				<rect x={0} y={horizon - 40} width={HEADER_WIDTH} height={80} fill="url(#horizonGlow)" opacity={0.18} style={{filter: 'blur(30px)'}} />
			</svg>
			{/* fade the floor into the dark at the bottom */}
			<AbsoluteFill style={{background: 'linear-gradient(180deg, rgba(4,6,12,0) 75%, rgba(4,6,12,0.85) 100%)'}} />
		</AbsoluteFill>
	);
};

const COL_H = 640;
const COL_W = Math.round(COL_H * 0.72);
const GAP = 26;
const PAD = 30;
const HERO_W = COL_W * 3 + GAP * 2;

/** The whole Hero picture at full width; each column shows its own part of it. */
const HeroArt: React.FC = () => (
	<div
		style={{
			position: 'absolute',
			width: HERO_W,
			height: COL_H,
			background: 'radial-gradient(ellipse 60% 75% at 50% 40%, #2A5BEA 0%, #10307F 45%, #070B1A 100%)',
			fontFamily: numberFont,
			color: '#fff',
		}}
	>
		<div
			style={{
				position: 'absolute',
				top: 150,
				width: '100%',
				textAlign: 'center',
				fontSize: 270,
				fontWeight: 900,
				letterSpacing: 10,
				color: 'rgba(200,215,255,0.22)',
				lineHeight: 1,
			}}
		>
			MY CAR
		</div>
		<Img
			src={staticFile('car/mycar-studio-side.png')}
			style={{position: 'absolute', left: (HERO_W - 1290) / 2, top: 255, width: 1290, filter: 'drop-shadow(0 30px 30px rgba(0,0,0,0.55))'}}
		/>
		<div style={{position: 'absolute', left: 0, right: 0, top: 600, height: 40, background: 'radial-gradient(ellipse 45% 100% at 50% 0%, rgba(0,0,0,0.5), rgba(0,0,0,0))'}} />
		<div style={{position: 'absolute', right: 40, top: 30, fontSize: 92, fontWeight: 800, fontFamily: textFont, letterSpacing: -1}}>9:41</div>
		<div style={{position: 'absolute', left: 40, bottom: 34, fontSize: 96, fontWeight: 800, fontFamily: textFont}}>31°</div>
		<div
			style={{
				position: 'absolute',
				right: 40,
				bottom: 44,
				fontSize: 40,
				fontWeight: 800,
				fontFamily: textFont,
				padding: '8px 22px',
				border: '4px solid rgba(255,255,255,0.9)',
				borderRadius: 14,
				background: '#05070D',
			}}
		>
			ABC 1234
		</div>
	</div>
);

const HeadUnit: React.FC = () => {
	const panelW = HERO_W + PAD * 2;
	const panelH = COL_H + PAD * 2;
	return (
		<div
			style={{
				position: 'absolute',
				left: CX - panelW / 2,
				top: SAFE.y + (SAFE.h - panelH) / 2,
				width: panelW,
				height: panelH,
				borderRadius: 64,
				background: 'linear-gradient(180deg, #0B0F1A 0%, #05070D 100%)',
				border: '5px solid rgba(140,170,255,0.25)',
				boxShadow: '0 0 0 2px rgba(0,0,0,0.6), 0 60px 160px rgba(31,79,216,0.55), 0 0 220px rgba(80,140,255,0.35)',
			}}
		>
			{[0, 1, 2].map((i) => (
				<div
					key={i}
					style={{
						position: 'absolute',
						left: PAD + i * (COL_W + GAP),
						top: PAD,
						width: COL_W,
						height: COL_H,
						borderRadius: 44,
						overflow: 'hidden',
					}}
				>
					<div style={{position: 'absolute', left: -i * (COL_W + GAP), top: 0}}>
						<HeroArt />
					</div>
				</div>
			))}
			{/* glass sheen */}
			<div
				style={{
					position: 'absolute',
					inset: 0,
					borderRadius: 64,
					background: 'linear-gradient(115deg, rgba(255,255,255,0.10) 0%, rgba(255,255,255,0) 32%)',
					pointerEvents: 'none',
				}}
			/>
		</div>
	);
};

type Tile = {file: string; x: number; y: number; size: number; rotate: number; blur?: number; opacity?: number};

// Centres of floating widget tiles, all outside the safe area.
const TILES: Tile[] = [
	{file: 'widget-service.png', x: 1520, y: 860, size: 560, rotate: -7},
	{file: 'widget-commute.png', x: 980, y: 1420, size: 500, rotate: 5},
	{file: 'widget-fuel.png', x: 1480, y: 1640, size: 420, rotate: -3, opacity: 0.9},
	{file: 'widget-tng.png', x: 470, y: 760, size: 420, rotate: -10, blur: 5, opacity: 0.6},
	{file: 'widget-weather-neon.png', x: 3730, y: 860, size: 560, rotate: 7},
	{file: 'widget-renewals.png', x: 4270, y: 1420, size: 500, rotate: -5},
	{file: 'widget-obd-neon.png', x: 3770, y: 1640, size: 420, rotate: 3, opacity: 0.9},
	{file: 'widget-parking-neon.png', x: 4780, y: 760, size: 420, rotate: 10, blur: 5, opacity: 0.6},
];

const FloatingTiles: React.FC = () => (
	<>
		{TILES.map((t) => (
			<Img
				key={t.file}
				src={staticFile(`widgets/${t.file}`)}
				style={{
					position: 'absolute',
					left: t.x - t.size / 2,
					top: t.y - t.size / 2,
					width: t.size,
					height: t.size,
					transform: `rotate(${t.rotate}deg)`,
					opacity: t.opacity ?? 1,
					filter: `${t.blur ? `blur(${t.blur}px) ` : ''}drop-shadow(0 40px 60px rgba(0,0,0,0.6)) drop-shadow(0 0 50px rgba(60,120,255,0.35))`,
				}}
			/>
		))}
	</>
);

export const StoreHeader: React.FC = () => (
	<AbsoluteFill>
		<Background />
		<FloatingTiles />
		<HeadUnit />
	</AbsoluteFill>
);
