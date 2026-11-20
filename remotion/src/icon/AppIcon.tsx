import React from 'react';
import {IconArt, type IconVariant} from './IconArt';

export type AppIconProps = {variant: IconVariant};

/** 1024×1024 square, full-bleed (iOS applies the corner mask). No logos; the only text is the GTCP wordmark. */
export const AppIcon: React.FC<AppIconProps> = ({variant}) => <IconArt variant={variant} />;
