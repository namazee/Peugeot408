import React from 'react';
import {AbsoluteFill} from 'remotion';
import {IconTile, type IconVariant} from './IconArt';

const FONT = 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif';
const TINT = '#E8B04A'; // example user tint for the Tinted appearance

const Label: React.FC<{children: React.ReactNode; color?: string; size?: number}> = ({children, color = '#9AA3B2', size = 15}) => (
	<div style={{fontFamily: FONT, fontSize: size, color, marginTop: 6, textAlign: 'center', whiteSpace: 'nowrap'}}>{children}</div>
);

const Sized: React.FC<{variant: IconVariant; size: number; shown?: number}> = ({variant, size, shown}) => (
	<div style={{display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
		<IconTile variant={variant} size={shown ?? size} />
		<Label>{shown ? `${size} (shown at ${shown})` : `${size} px`}</Label>
	</div>
);

const Ladder: React.FC<{variant: IconVariant; title: string}> = ({variant, title}) => (
	<div style={{width: 580}}>
		<div style={{fontFamily: FONT, fontSize: 22, fontWeight: 600, color: '#E8ECF3', marginBottom: 14}}>{title}</div>
		<div style={{display: 'flex', gap: 18, alignItems: 'flex-start'}}>
			<Sized variant={variant} size={1024} shown={220} />
			<Sized variant={variant} size={180} />
			<div style={{display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'center'}}>
				<Sized variant={variant} size={120} />
				<div style={{display: 'flex', gap: 14, alignItems: 'flex-end'}}>
					<Sized variant={variant} size={60} />
					<Sized variant={variant} size={40} />
				</div>
			</div>
		</div>
	</div>
);

const Placeholder: React.FC<{size: number; dark: boolean; hue: number}> = ({size, dark, hue}) => (
	<div
		style={{
			width: size,
			height: size,
			flexShrink: 0,
			borderRadius: size * 0.2237,
			background: dark
				? `linear-gradient(160deg, hsl(${hue} 18% 30%), hsl(${hue} 20% 18%))`
				: `linear-gradient(160deg, hsl(${hue} 55% 78%), hsl(${hue} 45% 62%))`,
		}}
	/>
);

const HomeScreen: React.FC<{variant: IconVariant; wallpaper: 'light' | 'dark'; title: string; tint?: string}> = ({variant, wallpaper, title, tint}) => {
	const dark = wallpaper === 'dark';
	const text = dark ? '#F2F4F8' : '#10131A';
	const cells: Array<number | 'me'> = [210, 30, 140, 280, 0, 'me', 50, 320, 100, 240, 15, 170];
	return (
		<div style={{display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
			<div
				style={{
					width: 330,
					height: 470,
					borderRadius: 46,
					border: '10px solid #0A0A0C',
					boxShadow: '0 0 0 2px #2A2D33',
					overflow: 'hidden',
					position: 'relative',
					background: dark
						? 'radial-gradient(120% 80% at 20% 0%, #23315C 0%, #0B0F1A 60%, #05070D 100%)'
						: 'radial-gradient(120% 80% at 20% 0%, #FFFFFF 0%, #DCE6F7 55%, #B9CBEA 100%)',
				}}
			>
				<div style={{display: 'flex', justifyContent: 'space-between', padding: '14px 26px 0', fontFamily: FONT, fontSize: 15, fontWeight: 600, color: text}}>
					<span>9:41</span>
					<span>●●●</span>
				</div>
				<div style={{display: 'grid', gridTemplateColumns: 'repeat(4, 60px)', columnGap: 12, rowGap: 14, padding: '26px 23px 0'}}>
					{cells.map((c, i) => (
						<div key={i} style={{display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
							{c === 'me' ? <IconTile variant={variant} size={60} tint={tint} /> : <Placeholder size={60} dark={dark} hue={c} />}
							<div style={{fontFamily: FONT, fontSize: 10.5, color: text, marginTop: 4, opacity: c === 'me' ? 1 : 0.5}}>
								{c === 'me' ? 'DashCraft' : '—'}
							</div>
						</div>
					))}
				</div>
				<div
					style={{
						position: 'absolute',
						left: 14,
						right: 14,
						bottom: 14,
						height: 84,
						borderRadius: 30,
						background: dark ? 'rgba(255,255,255,0.12)' : 'rgba(255,255,255,0.45)',
						display: 'flex',
						alignItems: 'center',
						justifyContent: 'space-around',
					}}
				>
					{[200, 120, 340].map((h) => (
						<Placeholder key={h} size={60} dark={dark} hue={h} />
					))}
					<IconTile variant={variant} size={60} tint={tint} />
				</div>
			</div>
			<Label color="#C9D1DE" size={16}>
				{title}
			</Label>
		</div>
	);
};

const CarPlay: React.FC = () => (
	<div style={{display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
		<div
			style={{
				width: 760,
				height: 400,
				borderRadius: 18,
				border: '8px solid #0A0A0C',
				boxShadow: '0 0 0 2px #2A2D33',
				background: 'linear-gradient(180deg, #0B0D12 0%, #050608 100%)',
				display: 'flex',
				overflow: 'hidden',
			}}
		>
			{/* Side bar: clock + recent apps at 40 px. */}
			<div style={{width: 74, background: 'rgba(255,255,255,0.06)', display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 14, gap: 16}}>
				<div style={{fontFamily: FONT, fontSize: 15, fontWeight: 600, color: '#F2F4F8'}}>9:41</div>
				<IconTile variant="dark" size={40} />
				<Placeholder size={40} dark hue={140} />
				<Placeholder size={40} dark hue={30} />
			</div>
			<div style={{flex: 1, display: 'grid', gridTemplateColumns: 'repeat(4, 120px)', justifyContent: 'center', alignContent: 'center', columnGap: 34, rowGap: 22}}>
				<div style={{display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
					<IconTile variant="dark" size={120} />
					<div style={{fontFamily: FONT, fontSize: 14, color: '#F2F4F8', marginTop: 6}}>DashCraft</div>
				</div>
				{[210, 140, 30, 280, 190, 0, 320].map((h) => (
					<div key={h} style={{display: 'flex', flexDirection: 'column', alignItems: 'center'}}>
						<Placeholder size={120} dark hue={h} />
						<div style={{fontFamily: FONT, fontSize: 14, color: '#F2F4F8', marginTop: 6, opacity: 0.5}}>—</div>
					</div>
				))}
			</div>
		</div>
		<Label color="#C9D1DE" size={16}>
			CarPlay-style dark dashboard · Dark at 120 and 40
		</Label>
	</div>
);

/** 1920×1080 contact sheet: every variant at real sizes, on home screens and a CarPlay mock. */
export const IconPreview: React.FC = () => (
	<AbsoluteFill style={{background: '#14161B', padding: '34px 50px', fontFamily: FONT}}>
		<div style={{display: 'flex', justifyContent: 'space-between'}}>
			<Ladder variant="default" title="Default (Any)" />
			<Ladder variant="dark" title="Dark" />
			<Ladder variant="tinted" title="Tinted (grayscale source)" />
		</div>
		<div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginTop: 36}}>
			<HomeScreen variant="default" wallpaper="light" title="Light wallpaper · Default at 60" />
			<HomeScreen variant="dark" wallpaper="dark" title="Dark wallpaper · Dark at 60" />
			<HomeScreen variant="tinted" wallpaper="dark" tint={TINT} title="Dark wallpaper · Tinted (amber) at 60" />
			<CarPlay />
		</div>
	</AbsoluteFill>
);
