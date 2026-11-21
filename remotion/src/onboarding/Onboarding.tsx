import React from 'react';
import {AbsoluteFill, Easing, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';
import {Icon} from '../shared/icons';
import {Column, SplitCard, timer} from '../shared/ui';
import {colors, numberFont, textFont} from '../shared/theme';

// Clips for the app's three first-run pages (played once with AVPlayer, muted).
export const ONBOARDING_FPS = 30;
export const WELCOME_FRAMES = 6 * ONBOARDING_FPS;
export const SETUP_FRAMES = 9 * ONBOARDING_FPS;
export const FLASH_FRAMES = 6 * ONBOARDING_FPS;

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const out = Easing.out(Easing.cubic);

const HeadUnit: React.FC<{children: React.ReactNode}> = ({children}) => (
	<div style={{width: 660, height: 440, display: 'flex', gap: 10, padding: 14, borderRadius: 32, background: '#050608', border: '2px solid rgba(255,255,255,0.08)'}}>
		{children}
	</div>
);

/** Page 1: the head unit fills with live cards. */
export const OnboardingWelcome: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const t = frame / fps;
	const enter = (i: number) => {
		const p = interpolate(t, [0.3 + i * 0.35, 1.1 + i * 0.35], [0, 1], {...clamp, easing: out});
		return {opacity: p, transform: `translateY(${(1 - p) * 40}px)`};
	};
	return (
		<AbsoluteFill style={{background: colors.background, alignItems: 'center', justifyContent: 'center'}}>
			<HeadUnit>
				<Column style={enter(0)}>
					<SplitCard scale={0.85} icon="moon" label="Maghrib" value={timer(2 * 3600 + 14 * 60 - t)} />
					<SplitCard scale={0.85} icon="calendar" label="Road tax" value="23 days" urgency="dueSoon" />
				</Column>
				<Column style={enter(1)}>
					<SplitCard scale={0.85} icon="wrench" label="Oil service" value={`${(1243 - Math.floor(t / 2)).toLocaleString('en')} km`} />
					<SplitCard scale={0.85} icon="fuel" label="Fuel avg" value="14.2 km/L" />
				</Column>
				<Column style={enter(2)}>
					<SplitCard scale={0.85} icon="cloud" label="API 57" value="31°" />
					<SplitCard scale={0.85} icon="parking" label="B2 · C14" value="IOI City" />
				</Column>
			</HeadUnit>
		</AbsoluteFill>
	);
};

/** Page 2: Settings → General → CarPlay → your car → Widgets → add Car Slot 1–5. */
export const OnboardingSetup: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const t = frame / fps;
	const path = ['Settings', 'General', 'CarPlay', 'My Car', 'Widgets'];
	const step = Math.min(Math.floor(interpolate(t, [0.4, 3.2], [0, path.length - 1], clamp)), path.length - 1);
	const listIn = interpolate(t, [3.2, 3.7], [0, 1], {...clamp, easing: out});
	const added = (i: number) => t > 4 + i * 0.75;

	return (
		<AbsoluteFill style={{background: colors.background, alignItems: 'center', justifyContent: 'center'}}>
			<div style={{width: 430, height: 820, borderRadius: 56, background: '#000', border: '6px solid #1c1f26', overflow: 'hidden', padding: '60px 24px 24px'}}>
				<div style={{display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap', marginBottom: 18}}>
					{path.slice(0, step + 1).map((p, i) => (
						<React.Fragment key={p}>
							{i > 0 ? <Icon name="chevron" size={18} color={colors.secondaryText} /> : null}
							<span style={{fontFamily: textFont, fontWeight: i === step ? 800 : 500, fontSize: i === step ? 30 : 18, color: i === step ? '#fff' : colors.secondaryText}}>{p}</span>
						</React.Fragment>
					))}
				</div>
				<div style={{opacity: listIn, transform: `translateY(${(1 - listIn) * 30}px)`}}>
					<div style={{fontFamily: textFont, fontWeight: 600, fontSize: 18, color: colors.secondaryText, margin: '10px 4px'}}>STACK 1</div>
					<div style={{borderRadius: 18, background: colors.surface, overflow: 'hidden'}}>
						{[1, 2, 3, 4, 5].map((n) => {
							const on = added(n - 1);
							const pop = interpolate(t, [4 + (n - 1) * 0.75, 4.25 + (n - 1) * 0.75], [1.25, 1], clamp);
							return (
								<div key={n} style={{display: 'flex', alignItems: 'center', gap: 16, padding: '20px 18px', borderTop: n > 1 ? '1px solid rgba(255,255,255,0.07)' : undefined}}>
									<div style={{width: 34, height: 34, borderRadius: 17, background: on ? '#34C759' : 'transparent', border: on ? 'none' : `3px solid #34C759`, display: 'flex', alignItems: 'center', justifyContent: 'center', transform: `scale(${on ? pop : 1})`}}>
										<Icon name={on ? 'check' : 'plus'} size={22} color={on ? '#fff' : '#34C759'} />
									</div>
									<div style={{width: 44, height: 44, borderRadius: 10, background: colors.accent, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
										<Icon name="car" size={28} color="#fff" />
									</div>
									<span style={{fontFamily: textFont, fontWeight: 600, fontSize: 26, color: '#fff'}}>Car Slot {n}</span>
								</div>
							);
						})}
					</div>
					<div style={{fontFamily: textFont, fontSize: 18, color: colors.secondaryText, margin: '14px 6px'}}>Up to 5 widgets in a stack. Many cars show Slot 1–3 side by side.</div>
				</div>
			</div>
		</AbsoluteFill>
	);
};

/** Page 3: "Test: flash all slots" labels every card, then the cards come back. */
export const OnboardingFlash: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();
	const t = frame / fps;
	const flashing = t > 1 && t < 4.6;
	const pulse = flashing ? 0.6 + 0.4 * Math.abs(Math.sin((t - 1) * 3)) : 0;
	const FlashCard: React.FC<{slot: number; part: string}> = ({slot, part}) => (
		<div style={{flex: 1, borderRadius: 12, background: colors.accent, boxShadow: `0 0 ${30 * pulse}px ${colors.accent}`, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4}}>
			<div style={{fontFamily: numberFont, fontWeight: 900, fontSize: 34, color: '#fff'}}>Slot {slot}</div>
			<div style={{fontFamily: textFont, fontWeight: 700, fontSize: 22, color: '#fff'}}>{part} ✓</div>
		</div>
	);
	const tap = interpolate(t, [0.5, 0.7, 0.9], [1, 0.92, 1], clamp);
	return (
		<AbsoluteFill style={{background: colors.background, alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 40}}>
			<HeadUnit>
				{[1, 2, 3].map((slot) => (
					<Column key={slot}>
						{flashing ? (
							<>
								<FlashCard slot={slot} part="Top" />
								<FlashCard slot={slot} part="Bottom" />
							</>
						) : slot === 1 ? (
							<>
								<SplitCard scale={0.85} icon="moon" label="Maghrib" value="2:13:52" />
								<SplitCard scale={0.85} icon="calendar" label="Road tax" value="23 days" urgency="dueSoon" />
							</>
						) : slot === 2 ? (
							<>
								<SplitCard scale={0.85} icon="wrench" label="Oil service" value="1,240 km" />
								<SplitCard scale={0.85} icon="fuel" label="Fuel avg" value="14.2 km/L" />
							</>
						) : (
							<>
								<SplitCard scale={0.85} icon="cloud" label="API 57" value="31°" />
								<SplitCard scale={0.85} icon="parking" label="B2 · C14" value="IOI City" />
							</>
						)}
					</Column>
				))}
			</HeadUnit>
			<div style={{padding: '16px 28px', borderRadius: 16, background: colors.surface, display: 'flex', alignItems: 'center', gap: 12, transform: `scale(${tap})`}}>
				<Icon name="check" size={26} color={colors.accent} />
				<span style={{fontFamily: textFont, fontWeight: 700, fontSize: 26, color: colors.accent}}>Test: flash all slots</span>
			</div>
		</AbsoluteFill>
	);
};
