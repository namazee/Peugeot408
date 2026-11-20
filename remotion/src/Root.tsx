import React from 'react';
import {Composition, Still} from 'remotion';
import {AppIcon, type AppIconProps} from './icon/AppIcon';
import {IconPreview} from './icon/IconPreview';
import {IconReveal, REVEAL_FPS, REVEAL_FRAMES, type IconRevealProps} from './icon/IconReveal';

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
	</>
);
