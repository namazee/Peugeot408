import React from 'react';
import {Composition, Still} from 'remotion';
import {AppIcon, type AppIconProps} from './icon/AppIcon';
import {IconPreview} from './icon/IconPreview';
import {IconReveal, REVEAL_FPS, REVEAL_FRAMES, type IconRevealProps} from './icon/IconReveal';
import {SHOWCASE_FPS, SHOWCASE_FRAMES, WidgetShowcase} from './showcase/WidgetShowcase';
import {AppPreview, PREVIEW_FPS, PREVIEW_FRAMES} from './preview/AppPreview';
import {FLASH_FRAMES, ONBOARDING_FPS, OnboardingFlash, OnboardingSetup, OnboardingWelcome, SETUP_FRAMES, WELCOME_FRAMES} from './onboarding/Onboarding';
import {SeasonalArt, type SeasonalArtProps} from './seasonal/SeasonalArt';
import {STORE_HEIGHT, STORE_WIDTH, StoreScreenshot, type StoreScreenshotProps} from './store/StoreScreenshot';
import {HEADER_HEIGHT, HEADER_WIDTH, StoreHeader} from './store/StoreHeader';

export const RemotionRoot: React.FC = () => (
	<>
		<Still id="AppIcon" component={AppIcon} width={1024} height={1024} defaultProps={{variant: 'default'} satisfies AppIconProps} />
		<Still id="IconPreview" component={IconPreview} width={1920} height={1080} />
		<Composition
			id="IconReveal"
			component={IconReveal}
			fps={REVEAL_FPS}
			durationInFrames={REVEAL_FRAMES}
			width={1080}
			height={1080}
			defaultProps={{format: 'square'} satisfies IconRevealProps}
			calculateMetadata={({props}) => ({width: 1080, height: props.format === 'vertical' ? 1920 : 1080})}
		/>
		<Composition id="OnboardingWelcome" component={OnboardingWelcome} fps={ONBOARDING_FPS} durationInFrames={WELCOME_FRAMES} width={720} height={900} />
		<Composition id="OnboardingSetup" component={OnboardingSetup} fps={ONBOARDING_FPS} durationInFrames={SETUP_FRAMES} width={720} height={900} />
		<Composition id="OnboardingFlash" component={OnboardingFlash} fps={ONBOARDING_FPS} durationInFrames={FLASH_FRAMES} width={720} height={900} />
		<Still
			id="StoreScreenshot"
			component={StoreScreenshot}
			width={STORE_WIDTH}
			height={STORE_HEIGHT}
			defaultProps={{file: '1-slots.png', headline: 'Your car screen, your way', subline: 'Five slots you design on your iPhone'} satisfies StoreScreenshotProps}
		/>
		<Still id="StoreHeader" component={StoreHeader} width={HEADER_WIDTH} height={HEADER_HEIGHT} />
		<Still id="SeasonalArt" component={SeasonalArt} width={600} height={600} defaultProps={{occasion: 'hariRaya'} satisfies SeasonalArtProps} />
		<Composition id="AppPreview" component={AppPreview} fps={PREVIEW_FPS} durationInFrames={PREVIEW_FRAMES} width={886} height={1920} />
		<Composition id="WidgetShowcase" component={WidgetShowcase} fps={SHOWCASE_FPS} durationInFrames={SHOWCASE_FRAMES} width={1920} height={720} />
	</>
);
