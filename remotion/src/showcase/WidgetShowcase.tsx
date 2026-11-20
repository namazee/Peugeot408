import React from 'react';
import {AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {Icon} from '../shared/icons';
import {CarPlayScreen, Column, SplitCard, timer} from '../shared/ui';
import {colors, numberFont, textFont} from '../shared/theme';

export const SHOWCASE_FPS = 30;
export const SHOWCASE_FRAMES = 18 * SHOWCASE_FPS;

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

/** Boost over time: cruise vacuum, then two pulls (5–8 s and 11–14 s). */
const boostAt = (t: number) => {
	const pull = (start: number) => {
		if (t < start || t > start + 3) return 0;
		const x = (t - start) / 3;
		return x < 0.45 ? Easing.out(Easing.cubic)(x / 0.45) : 1 - Easing.in(Easing.quad)((x - 0.45) / 0.55);
	};
	return -0.38 + 0.04 * Math.sin(t * 3) + 1.53 * Math.max(pull(5), pull(11));
};

const Gauge: React.FC<{value: number; rpm: number}> = ({value, rpm}) => {
	const min = -1;
	const max = 1.5;
	const p = Math.min(Math.max((value - min) / (max - min), 0), 1);
	const r = 150;
	const start = Math.PI * 0.75;
	const sweep = Math.PI * 1.5;
	const arc = (from: number, to: number) => {
		const a0 = start + sweep * from;
		const a1 = start + sweep * to;
		const large = a1 - a0 > Math.PI ? 1 : 0;
		return `M ${180 + r * Math.cos(a0)} ${180 + r * Math.sin(a0)} A ${r} ${r} 0 ${large} 1 ${180 + r * Math.cos(a1)} ${180 + r * Math.sin(a1)}`;
	};
	const hot = value > 0.9;
	return (
		<div style={{position: 'relative', width: 360, height: 370, margin: '0 auto'}}>
			<svg width={360} height={360} style={{position: 'absolute', top: -10}}>
				<path d={arc(0, 1)} stroke="rgba(255,255,255,0.12)" strokeWidth={22} fill="none" strokeLinecap="round" />
				<path d={arc(0, Math.max(p, 0.001))} stroke={hot ? colors.glow : colors.accent} strokeWidth={22} fill="none" strokeLinecap="round" style={{filter: `drop-shadow(0 0 ${hot ? 16 : 8}px ${hot ? colors.glow : colors.accent})`}} />
			</svg>
			<div style={{position: 'absolute', top: 118, width: '100%', textAlign: 'center'}}>
				<div style={{fontFamily: numberFont, fontWeight: 900, fontSize: 78, color: '#fff', fontVariantNumeric: 'tabular-nums'}}>
					{value >= 0 ? '+' : ''}
					{value.toFixed(2)}
				</div>
			</div>
			<div style={{position: 'absolute', top: 312, width: '100%', textAlign: 'center', fontFamily: textFont, fontWeight: 600, fontSize: 24, color: colors.secondaryText}}>
				bar boost · {Math.round(rpm).toLocaleString('en')} rpm
			</div>
		</div>
	);
};

export const WidgetShowcase: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const t = frame / fps;

	const enter = (i: number) => {
		const p = interpolate(t, [0.5 + i * 0.3, 1.3 + i * 0.3], [0, 1], {...clamp, easing: Easing.out(Easing.cubic)});
		return {opacity: p, transform: `translateY(${(1 - p) * 60}px) scale(${0.96 + 0.04 * p})`};
	};

	// Values that tick.
	const prayerLeft = 1 * 3600 + 23 * 60 + 45 - t; // live countdown to Asar
	const serviceKm = 1262 - Math.floor(interpolate(t, [2.5, 16], [0, 22], clamp)); // km to the oil service
	const kmChanged = (t > 2.5 && t < 16 && (t * 2) % 1.35 < 0.2) ? 1 : 0;
	const boost = boostAt(t);
	const rpm = 1900 + Math.max(boost + 0.38, 0) * 2400;

	const photos = ['car/mycar-studio-front-three-quarter.jpg', 'car/mycar-studio-side.jpg', 'car/mycar-studio-rear-three-quarter.jpg'];
	const photoIndex = Math.floor(t / 4) % photos.length;
	const fade = interpolate(t % 4, [3.2, 4], [0, 1], clamp);

	const outro = interpolate(t, [16.2, 17], [0, 1], clamp);
	const fadeIn = interpolate(frame, [0, 15], [0, 1], clamp);

	return (
		<AbsoluteFill style={{opacity: fadeIn}}>
			<CarPlayScreen time="4:01">
				<Column style={enter(0)}>
					<SplitCard scale={1.45} icon="moon" label="Asar 5:24 PM" value={timer(prayerLeft)} />
					<SplitCard scale={1.45} icon="calendar" label="Road tax" value="23 days" urgency="dueSoon" />
				</Column>
				<Column style={enter(1)}>
					<SplitCard scale={1.45} icon="wrench" label="Oil service" value={`${serviceKm.toLocaleString('en')} km`} highlight={kmChanged * 0.6} />
					<SplitCard scale={1.45} icon="fuel" label="Fuel avg" value="14.2 km/L" />
				</Column>
				<Column style={{...enter(2), justifyContent: 'center'}}>
					<div style={{display: 'flex', alignItems: 'center', gap: 10, paddingLeft: 10}}>
						<Icon name="gauge" size={26} color={colors.accent} />
						<span style={{fontFamily: textFont, fontWeight: 700, fontSize: 20, color: colors.secondaryText, letterSpacing: 1}}>OBD2 · LIVE</span>
					</div>
					<Gauge value={boost} rpm={rpm} />
				</Column>
				<Column style={{...enter(3), padding: 0, overflow: 'hidden', position: 'relative'}}>
					<Img src={staticFile(photos[photoIndex])} style={{position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover'}} />
					<Img
						src={staticFile(photos[(photoIndex + 1) % photos.length])}
						style={{position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', opacity: fade}}
					/>
					<div style={{position: 'absolute', left: 16, bottom: 16, padding: '8px 14px', borderRadius: 10, background: 'rgba(0,0,0,0.55)', fontFamily: textFont, fontWeight: 600, fontSize: 20, color: '#fff'}}>
						Photo Frame
					</div>
				</Column>
			</CarPlayScreen>

			<AbsoluteFill
				style={{
					background: `rgba(0,0,0,${0.82 * outro})`,
					alignItems: 'center',
					justifyContent: 'center',
					flexDirection: 'column',
					gap: 14,
					opacity: outro,
				}}
			>
				<div style={{fontFamily: textFont, fontWeight: 800, fontSize: 72, color: '#fff', letterSpacing: -1}}>Car Slots for CarPlay</div>
				<div style={{fontFamily: textFont, fontWeight: 500, fontSize: 32, color: colors.secondaryText}}>Set it up on your phone. Your head unit follows.</div>
			</AbsoluteFill>
		</AbsoluteFill>
	);
};
