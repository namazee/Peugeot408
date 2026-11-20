import React from 'react';
import {AbsoluteFill} from 'remotion';
import {Icon, type IconName} from './icons';
import {colors, numberFont, radius, textFont, urgencyColor, type Urgency} from './theme';

/** One Split card, drawn like SlotCardView in the app: icon + short label + one big value. */
export const SplitCard: React.FC<{
	icon: IconName;
	label: string;
	value: React.ReactNode;
	urgency?: Urgency;
	scale?: number;
	highlight?: number; // 0…1 glow when the value just changed
	style?: React.CSSProperties;
}> = ({icon, label, value, urgency = 'ok', scale = 1, highlight = 0, style}) => (
	<div
		style={{
			flex: 1,
			borderRadius: radius.card * scale,
			background: colors.surface,
			border: `${(urgency === 'ok' ? 1 : 2) * scale}px solid ${urgency === 'ok' ? 'rgba(255,255,255,0.07)' : urgencyColor(urgency)}`,
			boxShadow: highlight > 0 ? `0 0 ${40 * highlight * scale}px ${colors.accent}` : undefined,
			padding: 14 * scale,
			display: 'flex',
			flexDirection: 'column',
			justifyContent: 'space-between',
			overflow: 'hidden',
			...style,
		}}
	>
		<div style={{display: 'flex', alignItems: 'center', gap: 8 * scale}}>
			<Icon name={icon} size={22 * scale} color={urgencyColor(urgency, colors.accent)} />
			<span style={{fontFamily: textFont, fontWeight: 600, fontSize: 17 * scale, color: colors.secondaryText, whiteSpace: 'nowrap'}}>{label}</span>
		</div>
		<div
			style={{
				fontFamily: numberFont,
				fontWeight: 800,
				fontSize: 38 * scale,
				lineHeight: 1.05,
				color: urgencyColor(urgency),
				fontVariantNumeric: 'tabular-nums',
				whiteSpace: 'nowrap',
			}}
		>
			{value}
		</div>
	</div>
);

/** A tall CarPlay widget column (the 408 shows 3 of these). */
export const Column: React.FC<{children: React.ReactNode; scale?: number; style?: React.CSSProperties}> = ({children, scale = 1, style}) => (
	<div
		style={{
			flex: 1,
			display: 'flex',
			flexDirection: 'column',
			gap: 8 * scale,
			padding: 9 * scale,
			borderRadius: radius.widget * scale,
			background: `radial-gradient(circle at 100% 0%, ${colors.accent}55, transparent 55%), linear-gradient(135deg, ${colors.surface}, ${colors.background})`,
			...style,
		}}
	>
		{children}
	</div>
);

/** The head-unit frame: a narrow dock on the left with generic app shapes, then the widget area. */
export const CarPlayScreen: React.FC<{children: React.ReactNode; time?: string; scale?: number}> = ({children, time = '8:42', scale = 1}) => (
	<AbsoluteFill style={{background: '#000', flexDirection: 'row', padding: 18 * scale, gap: 18 * scale}}>
		<div
			style={{
				width: 92 * scale,
				borderRadius: 26 * scale,
				background: '#101217',
				display: 'flex',
				flexDirection: 'column',
				alignItems: 'center',
				padding: `${18 * scale}px 0`,
				gap: 16 * scale,
			}}
		>
			<div style={{fontFamily: textFont, fontWeight: 700, fontSize: 20 * scale, color: '#fff'}}>{time}</div>
			{['#2E7D32', '#1F4FD8', '#C62828', '#F9A825'].map((c) => (
				<div key={c} style={{width: 56 * scale, height: 56 * scale, borderRadius: 14 * scale, background: c, opacity: 0.85}} />
			))}
			<div style={{flex: 1}} />
			<div style={{width: 40 * scale, height: 40 * scale, borderRadius: 10 * scale, border: `3px solid #fff`, opacity: 0.8}} />
		</div>
		<div style={{flex: 1, display: 'flex', gap: 18 * scale}}>{children}</div>
	</AbsoluteFill>
);

/** Short caption, top centre. */
export const Caption: React.FC<{text: string; opacity: number; y?: number; size?: number}> = ({text, opacity, y = 0, size = 44}) => (
	<div
		style={{
			position: 'absolute',
			left: 0,
			right: 0,
			top: 70,
			transform: `translateY(${y}px)`,
			opacity,
			textAlign: 'center',
			fontFamily: textFont,
			fontWeight: 700,
			fontSize: size,
			color: '#fff',
			letterSpacing: -0.5,
		}}
	>
		{text}
	</div>
);

/** Formats seconds as H:MM:SS / M:SS like SwiftUI's Text(date, style: .timer). */
export const timer = (seconds: number) => {
	const s = Math.max(0, Math.floor(seconds));
	const h = Math.floor(s / 3600);
	const m = Math.floor((s % 3600) / 60);
	const sec = s % 60;
	return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}` : `${m}:${String(sec).padStart(2, '0')}`;
};
