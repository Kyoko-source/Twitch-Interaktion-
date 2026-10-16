import React from 'react';
import {Cable,Shapes,Activity,ListOrdered,SlidersHorizontal,SlidersVertical,Workflow,Hash,BatteryCharging,Compass} from 'lucide-react';
const ICONS={wires:Cable,glyphs:Shapes,frequency:Activity,sequence:ListOrdered,relays:SlidersHorizontal,sliders:SlidersVertical,pipes:Workflow,vectors:Hash,capacitors:BatteryCharging,compass:Compass};
export function ModuleMark({kind,size=22}){const Icon=ICONS[kind]||Activity;return <Icon size={size} strokeWidth={1.7} aria-hidden="true"/>;}
