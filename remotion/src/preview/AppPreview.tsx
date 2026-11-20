import React from 'react';
import {AbsoluteFill, Easing, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {Icon} from '../shared/icons';
import {Column, SplitCard} from '../shared/ui';
import {colors, numberFont, textFont} from '../shared/theme';

export const PREVIEW_FPS = 30;
export const PREVIEW_FRAMES = 20 * PREVIEW_FPS;

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const ease = Easing.inOut(Easing.cubic);

/** Types `text` progressively between start and end seconds. */
const typed = (text: string, t: number, start: number, end: number) => {
	const n = Math.round(interpolate(t, [start, end], [0, text.length], clamp));
	return text.slice(0, n);
};

const StatusBar: React.FC = () => (
	<div style={{height: 110, display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', padding: '0 56px 18px', fontFamily: textFont, fontWeight: 700, fontSize: 34, color: '#fff'}}>
		<span>9:41</span>
		<span style={{display: 'flex', gap: 10}}>
			<span style={{width: 40, height: 22, borderRadius: 6, border: '3px solid #fff', position: 'relative'}}>
				<span style={{position: 'absolute', inset: 3, background: '#fff', borderRadius: 2, width: 26}} />
			</span>
		</span>
	</div>
);

const Row: React.FC<{left: string; sub: string; right: string; accent?: string; opacity?: number; y?: number}> = ({left, sub, right, accent, opacity = 1, y = 0}) => (
	<div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '26px 32px', borderTop: '1px solid rgba(255,255,255,0.08)', opacity, transform: `translateY(${y}px)`}}>
		<div>
			<div style={{fontFamily: textFont, fontWeight: 700, fontSize: 34, color: '#fff'}}>{left}</div>
			<div style={{fontFamily: textFont, fontWeight: 500, fontSize: 26, color: colors.secondaryText, marginTop: 6}}>{sub}</div>
		</div>
		<div style={{textAlign: 'right'}}>
			<div style={{fontFamily: numberFont, fontWeight: 800, fontSize: 34, color: '#fff'}}>{right}</div>
			{accent ? <div style={{fontFamily: textFont, fontWeight: 600, fontSize: 26, color: colors.accent, marginTop: 6}}>{accent}</div> : null}
		</div>
	</div>
);

const Field: React.FC<{label: string; value: string; unit: string; active: boolean}> = ({label, value, unit, active}) => (
	<div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '30px 32px', borderTop: '1px solid rgba(255,255,255,0.08)'}}>
		<span style={{fontFamily: textFont, fontWeight: 500, fontSize: 34, color: '#fff'}}>{label}</span>
		<span style={{fontFamily: numberFont, fontWeight: 700, fontSize: 36, color: value ? '#fff' : colors.secondaryText}}>
			{value || unit}
			{active ? <span style={{display: 'inline-block', width: 3, height: 38, background: colors.accent, marginLeft: 4, verticalAlign: 'middle'}} /> : null}
			{value ? <span style={{color: colors.secondaryText, marginLeft: 10, fontSize: 28}}>{unit}</span> : null}
		</span>
	</div>
);

const Caption: React.FC<{text: string; t: number; from: number; to: number}> = ({text, t, from, to}) => {
	const o = Math.min(interpolate(t, [from, from + 0.4], [0, 1], clamp), interpolate(t, [to - 0.4, to], [1, 0], clamp));
	return (
		<div style={{position: 'absolute', left: 50, right: 50, bottom: 120, opacity: o, transform: `translateY(${(1 - o) * 20}px)`, textAlign: 'center', fontFamily: textFont, fontWeight: 800, fontSize: 52, color: '#fff', textShadow: '0 4px 30px #000'}}>
			{text}
		</div>
	);
};

/** Logging a fill-up and watching the CarPlay card update (App Store / TestFlight preview, portrait). */
export const AppPreview: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const t = frame / fps;

	// Scene timing (seconds).
	const sheet = interpolate(t, [3.5, 4.2], [0, 1], {...clamp, easing: ease}) - interpolate(t, [9.6, 10.2], [0, 1], {...clamp, easing: ease});
	const saved = t > 10;
	const kmPerLitre = interpolate(t, [10.6, 12], [14.2, 14.4], clamp);
	const newRow = interpolate(t, [10.2, 10.8], [0, 1], {...clamp, easing: Easing.out(Easing.cubic)});
	const toCar = interpolate(t, [13.6, 14.6], [0, 1], {...clamp, easing: ease});
	const carGlow = interpolate(t, [15.2, 15.8, 17.5], [0, 1, 0], clamp);
	const carValue = t < 15.4 ? '14.2 km/L' : '14.4 km/L';
	const savePress = interpolate(t, [9.2, 9.4, 9.6], [1, 0.9, 1], clamp);

	return (
		<AbsoluteFill style={{background: '#000'}}>
			{/* Phone UI */}
			<AbsoluteFill style={{opacity: 1 - toCar, transform: `scale(${1 - 0.08 * toCar})`}}>
				<StatusBar />
				<div style={{padding: '10px 32px 20px', fontFamily: textFont, fontWeight: 800, fontSize: 66, color: '#fff'}}>Fuel Log</div>
				{/* Head-unit card preview */}
				<div style={{margin: '0 32px', height: 300, display: 'flex', gap: 20}}>
					<Column scale={1.6} style={{flex: '0 0 300px'}}>
						<SplitCard scale={1.4} icon="fuel" label="Fuel avg" value={`${kmPerLitre.toFixed(1)} km/L`} highlight={saved ? interpolate(t, [10.6, 11, 12], [0, 1, 0], clamp) : 0} />
					</Column>
					<div style={{flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 10, fontFamily: textFont}}>
						<div style={{fontWeight: 600, fontSize: 28, color: colors.secondaryText}}>Last price</div>
						<div style={{fontFamily: numberFont, fontWeight: 800, fontSize: 44, color: '#fff'}}>RM 2.05/L</div>
						<div style={{fontWeight: 600, fontSize: 28, color: colors.secondaryText, marginTop: 10}}>This month</div>
						<div style={{fontFamily: numberFont, fontWeight: 800, fontSize: 44, color: '#fff'}}>{saved ? 'RM 226' : 'RM 151'}</div>
					</div>
				</div>
				<div style={{margin: '40px 32px 0', padding: '28px 32px', borderRadius: 24, background: colors.surface, display: 'flex', alignItems: 'center', gap: 16, transform: `scale(${t > 2.8 && t < 3.6 ? 0.97 : 1})`}}>
					<Icon name="fuel" size={40} color={colors.accent} />
					<span style={{fontFamily: textFont, fontWeight: 700, fontSize: 36, color: colors.accent}}>Add fill-up</span>
				</div>
				<div style={{margin: '30px 32px 0', borderRadius: 24, background: colors.surface, overflow: 'hidden'}}>
					{newRow > 0 ? <Row left="Today" sub="19,480 km · 36.80 L · RON95" right="RM 75.44" accent="14.4 km/L" opacity={newRow} y={(1 - newRow) * -30} /> : null}
					<Row left="11 Nov" sub="18,950 km · 37.20 L · RON95" right="RM 76.26" accent="14.2 km/L" />
					<Row left="2 Nov" sub="18,420 km · 36.50 L · RON95" right="RM 74.83" accent="14.3 km/L" />
					<Row left="23 Oct" sub="17,900 km · 42.00 L · RON95" right="RM 86.10" />
				</div>

				{/* Add fill-up sheet */}
				<AbsoluteFill style={{background: `rgba(0,0,0,${0.5 * sheet})`}}>
					<div style={{position: 'absolute', left: 0, right: 0, bottom: 0, height: 1500, transform: `translateY(${(1 - sheet) * 1550}px)`, background: '#111318', borderTopLeftRadius: 40, borderTopRightRadius: 40}}>
						<div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '36px 40px'}}>
							<span style={{fontFamily: textFont, fontSize: 34, color: colors.accent}}>Cancel</span>
							<span style={{fontFamily: textFont, fontWeight: 700, fontSize: 36, color: '#fff'}}>New fill-up</span>
							<span style={{fontFamily: textFont, fontWeight: 700, fontSize: 34, color: colors.accent, transform: `scale(${savePress})`, display: 'inline-block'}}>Save</span>
						</div>
						<div style={{margin: '10px 32px', borderRadius: 24, background: colors.surface, overflow: 'hidden'}}>
							<Field label="Date" value="Today" unit="" active={false} />
							<Field label="Odometer" value={typed('19480', t, 4.6, 5.6).replace(/(\d+)(\d{3})$/, '$1,$2')} unit="km" active={t > 4.5 && t < 5.8} />
							<Field label="Litres" value={typed('36.80', t, 6, 6.8)} unit="L" active={t > 5.9 && t < 7} />
							<Field label="Total" value={typed('75.44', t, 7.2, 8)} unit="RM" active={t > 7.1 && t < 8.2} />
							<Field label="Price per litre" value={t > 8.1 ? 'RM 2.05/L' : ''} unit="" active={false} />
						</div>
						<div style={{margin: '24px 32px', borderRadius: 24, background: colors.surface, padding: '26px 32px', display: 'flex', justifyContent: 'space-between', alignItems: 'center'}}>
							<span style={{fontFamily: textFont, fontSize: 34, color: '#fff'}}>Full tank</span>
							<span style={{width: 100, height: 60, borderRadius: 30, background: '#34C759', position: 'relative'}}>
								<span style={{position: 'absolute', right: 4, top: 4, width: 52, height: 52, borderRadius: 26, background: '#fff'}} />
							</span>
						</div>
					</div>
				</AbsoluteFill>
			</AbsoluteFill>

			{/* The head unit updates by itself */}
			<AbsoluteFill style={{opacity: toCar, justifyContent: 'center', alignItems: 'center', transform: `scale(${0.92 + 0.08 * toCar})`}}>
				<div style={{fontFamily: textFont, fontWeight: 700, fontSize: 32, color: colors.secondaryText, marginBottom: 30, letterSpacing: 2}}>ON THE HEAD UNIT</div>
				<div style={{width: 800, height: 600, display: 'flex', gap: 14, padding: 18, borderRadius: 40, background: '#050608', border: '2px solid rgba(255,255,255,0.08)'}}>
					<Column scale={1.1}>
						<SplitCard scale={1.05} icon="moon" label="Asar" value="1:12:40" />
						<SplitCard scale={1.05} icon="calendar" label="Road tax" value="23 days" urgency="dueSoon" />
					</Column>
					<Column scale={1.1}>
						<SplitCard scale={1.05} icon="wrench" label="Oil service" value="1,240 km" />
						<SplitCard scale={1.05} icon="fuel" label="Fuel avg" value={carValue} highlight={carGlow} />
					</Column>
					<Column scale={1.1}>
						<SplitCard scale={1.05} icon="cloud" label="API 57" value="31°" />
						<SplitCard scale={1.05} icon="parking" label="B2 · C14" value="IOI City" />
					</Column>
				</div>
			</AbsoluteFill>

			<Caption text="Log a fill-up in seconds" t={t} from={0.3} to={3.4} />
			<Caption text="km/L, full-to-full" t={t} from={10.4} to={13.4} />
			<Caption text="Your car screen updates by itself" t={t} from={14.8} to={19.8} />
		</AbsoluteFill>
	);
};
