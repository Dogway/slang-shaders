#version 450

/*
   Gaussian blur 'sharp' - horizontal pass, dynamic range, resizable
   
   Copyright (C) 2020 guest(r) - guest.r@gmail.com

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

   Anti-Ringing inspired by Hyllian
   
*/ 


layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float SIZEH;
	float SIGMA_H;
	float HSHARP0;
	float HAR;
	float HSHAR;
} params;

#pragma parameter SIZEH "Horizontal Blur Radius" 5.0 0.0 40.0 1.0 
#define SIZEH params.SIZEH

#pragma parameter SIGMA_H "Horizontal Blur Sigma" 0.70 0.1 15.0 0.05
#define SIGMA_H params.SIGMA_H

#pragma parameter HSHARP0 "Horizontal Sharpness Filter 'Range'" 0.8 0.8 20.0 0.2
#define HSHARP0 params.HSHARP0

#pragma parameter HSHAR "Sharpness Definition - Horizontal" 0.5 0.0 2.0 0.05
#define HSHAR params.HSHAR

#pragma parameter HAR "Horizontal Anti-Ringing" 0.5 0.0 1.0 0.1
#define HAR params.HAR

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define COMPAT_TEXTURE(c,d) texture(c,d)
#define SourceSize params.SourceSize

float invsqrsigma = 1.0/(2.0*SIGMA_H*SIGMA_H);

float gaussian(float x)
{
	return exp(-x*x*invsqrsigma);
}

void main()
{
	float f = fract(SourceSize.x * vTexCoord.x);
	f = 0.5 - f;
	vec2 tex = floor(SourceSize.xy * vTexCoord)*SourceSize.zw + 0.5*SourceSize.zw;
	vec3 color = vec3(0.0);
	vec2 dx  = vec2(SourceSize.z, 0.0);

	float w;
	float wsum = 0.0;
	vec3 pixel;
	float n = -SIZEH;

	vec3 cmax = COMPAT_TEXTURE(Source, tex).rgb;
	vec3 cmin = cmax;
	float sharp = (HSHARP0 > 0.85) ? gaussian(HSHARP0) : 0.0;
	float FPR = HSHARP0;
	float wnorm = 1.0/(1.0-sharp);
	float fpx = 0.0;

	do
	{	
	
		w = (gaussian(n+f) - sharp)*wnorm;
		
		if (HSHARP0 > 0.85)
		{
			if (abs(n+f) > FPR) { if (n < 0.0) fpx = -(n+f+FPR)/FPR; else fpx = (n+f-FPR)/FPR; fpx = min(fpx, 1.0);}
			if (abs(n) <= 2.0*FPR) { cmax = max(cmax, pixel); cmin = min(cmin, pixel); }
			if (w < 0.0) w = clamp(w, mix(-0.18, 0.0, pow(fpx,HSHAR)), 0.0);
		}
		
		pixel  = COMPAT_TEXTURE(Source, tex + n*dx).rgb;
		color  = color + w * pixel;
		wsum   = wsum + w;
		n = n + 1.0;
		
	} while (n <= SIZEH);

	color = color / wsum;
	if (HSHARP0 > 0.85) color = mix(clamp(color, 0.0, 1.0), clamp(color, cmin, cmax), HAR);
	
	FragColor = vec4(color, 1.0);
}