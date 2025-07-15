precision highp float;

varying vec2 v_TexCoord;
varying vec4 v_Color;
varying float v_Texture;

uniform sampler2D u_tex0;
uniform sampler2D u_tex1;
uniform sampler2D u_tex2;
uniform sampler2D u_tex3;

uniform vec3 u_BorderColorOuter;
uniform vec3 u_BorderColorInner;

uniform vec3 u_TrackColorOuter;
uniform vec3 u_TrackColorInner;

uniform vec4 u_ShadowColor;

uniform float u_BorderWidth;

uniform float u_Time;


mat2 Rot(float a)
{
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}


// Created by inigo quilez - iq/2014
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
vec2 hash( vec2 p )
{
    p = vec2( dot(p,vec2(2127.1,81.17)), dot(p,vec2(1269.5,283.37)) );
	return fract(sin(p)*43758.5453);
}

float noise( in vec2 p )
{
    vec2 i = floor( p );
    vec2 f = fract( p );
	
	vec2 u = f*f*(3.0-2.0*f);

    float n = mix( mix( dot( -1.0+2.0*hash( i + vec2(0.0,0.0) ), f - vec2(0.0,0.0) ), 
                        dot( -1.0+2.0*hash( i + vec2(1.0,0.0) ), f - vec2(1.0,0.0) ), u.x),
                   mix( dot( -1.0+2.0*hash( i + vec2(0.0,1.0) ), f - vec2(0.0,1.0) ), 
                        dot( -1.0+2.0*hash( i + vec2(1.0,1.0) ), f - vec2(1.0,1.0) ), u.x), u.y);
	return 0.5 + 0.5*n;
}


vec3 effect(vec2 tuv, float iTime){
    #define S(a,b,t) smoothstep(a,b,t)
    //vec2 uv = fragCoord/iResolution.xy;
    float ratio = 2.0;//iResolution.x / iResolution.y;

    tuv -= .5;

    // rotate with Noise
    float degree = noise(vec2(iTime*.1, tuv.x*tuv.y));

    tuv.y *= 1./ratio;
    tuv *= Rot(radians((degree-.5)*720.+180.));
	tuv.y *= ratio;

    
    // Wave warp with sin
    float frequency = 5.;
    float amplitude = 10.;
    float speed = iTime * 5.;
    tuv.x += sin(tuv.y*frequency+speed)/amplitude;
   	tuv.y += sin(tuv.x*frequency*1.5+speed)/(amplitude*.5);
    
    
    // draw the image
    vec3 colorYellow = vec3(.957, .804, .623);
    vec3 colorDeepBlue = vec3(.192, .384, .933);
    vec3 layer1 = mix(colorYellow, colorDeepBlue, S(-.3, .2, (tuv*Rot(radians(-5.))).x));
    
    vec3 colorRed = vec3(.910, .510, .8);
    vec3 colorBlue = vec3(0.350, .71, .953);
    vec3 layer2 = mix(colorRed, colorBlue, S(-.3, .2, (tuv*Rot(radians(-5.))).x));
    
    vec3 finalComp = mix(layer1, layer2, S(.5, -.3, tuv.y));
    
    return finalComp;
}

vec4 sliderFast(vec4 sliderTexture, vec2 diller) {
    #define borderStart 0.06640625 // 34/512
    #define baseBorderWidth 0.126953125 // 65/512
    #define blend 0.01

    #define maxBorderWidth (1.0 - borderStart)
    #define slope ((maxBorderWidth - baseBorderWidth) / 9.0)

    float distance = sliderTexture.r * 2.0 - 1.0;
    float distance_inv = 1.0 - distance;

    vec4 effecFinal = vec4(effect(diller, u_Time), v_Color.a);

    vec4 borderColorOuter = effecFinal;//vec4(u_BorderColorOuter.rgb, v_Color.a);
    vec4 borderColorInner = effecFinal;//vec4(u_BorderColorInner.rgb, v_Color.a);
    vec4 outerShadow = vec4(u_ShadowColor.rgb, u_ShadowColor.a * distance_inv / borderStart * borderColorInner.a);
    vec4 bodyColorOuter = vec4(u_TrackColorOuter.rgb, v_Color.a * 0.6);
    vec4 bodyColorInner = vec4(u_TrackColorInner.rgb, v_Color.a * 0.6);

    // border width scaling without branch:
    float t = clamp((u_BorderWidth - 1.0) / 8.99, 0.0, 1.0); // normalized between 0 and 1 for [1, 9.99]
    float borderWidthScaled = mix(baseBorderWidth, slope * 8.99 + baseBorderWidth, t);

    float borderMid = borderStart + borderWidthScaled * 0.5;
    float borderEnd = borderStart + borderWidthScaled;

    // Interpolate border colors smoothly
    float borderMixFactor = smoothstep(borderMid - borderWidthScaled * 0.25, borderMid + borderWidthScaled * 0.25, distance_inv);
    vec4 borderColorMix = mix(borderColorOuter, borderColorInner, borderMixFactor);

    // Interpolate body colors smoothly
    float bodyMixFactor = (distance_inv - borderEnd) / (1.0 - borderEnd);
    bodyMixFactor = clamp(bodyMixFactor, 0.0, 1.0);
    vec4 bodyColorMix = mix(bodyColorOuter, bodyColorInner, bodyMixFactor);

    // Replace borderColorMix with outerShadow if u_BorderWidth < 0.01 (smooth step)
    float borderWidthLowFactor = smoothstep(0.01, 0.02, u_BorderWidth); // 0 at very low width, 1 when above 0.02
    borderColorMix = mix(outerShadow, borderColorMix, borderWidthLowFactor);

    // Replace bodyColorMix with borderColorMix if u_BorderWidth > 9.99 (smooth step)
    float borderWidthHighFactor = smoothstep(9.98, 9.99, u_BorderWidth); // 0 below 9.98, 1 above 9.99
    bodyColorMix = mix(bodyColorMix, borderColorMix, borderWidthHighFactor);

    // Now handle sliderTexture output based on distance_inv with smoothstep blending

    // Compute smooth transitions at borderStart and borderEnd
    float s0 = smoothstep(borderStart - blend, borderStart + blend, distance_inv);
    float s1 = smoothstep(borderEnd - blend, borderEnd + blend, distance_inv);

    // OuterShadow to borderColorMix blending around borderStart
    vec4 colorStartBlend = mix(outerShadow, borderColorMix, s0);

    // borderColorMix to bodyColorMix blending around borderEnd
    vec4 colorEndBlend = mix(borderColorMix, bodyColorMix, s1);

    // Combine the two regions with smoothstep ramps:
    float between = smoothstep(borderStart + blend, borderEnd - blend, distance_inv);

    // Final color: interpolate between start blend and end blend using between
    sliderTexture = mix(colorStartBlend, colorEndBlend, between);

    return sliderTexture;
}

vec4 slider(vec4 sliderTexture) {
    /*
    #define borderStart 0.06640625 // 34/512
    #define baseBorderWidth 0.126953125 // 65/512
    #define blend 0.01

    #define maxBorderWidth 1.0 - borderStart

    #define slope (maxBorderWidth - baseBorderWidth) / 9.0
    */
    float distance = sliderTexture.r * 2.0 - 1.0;

    float distance_inv = 1.0 - distance;

    vec4 borderColorOuter = vec4(u_BorderColorOuter.rgb, v_Color.a);
    vec4 borderColorInner = vec4(u_BorderColorInner.rgb, v_Color.a);

    //Original was vec4 outerShadow = vec4(vec3(0.0), 0.5 * distance_inv / borderStart * borderColorInner.a);
    vec4 outerShadow = vec4(u_ShadowColor.rgb, u_ShadowColor.a * distance_inv / borderStart * borderColorInner.a);

    vec4 bodyColorOuter = vec4(u_TrackColorOuter.rgb, v_Color.a * 0.6);
    vec4 bodyColorInner = vec4(u_TrackColorInner.rgb, v_Color.a * 0.6);

    float borderWidthScaled = u_BorderWidth < 1.0 ? u_BorderWidth * baseBorderWidth : (u_BorderWidth - 1.0) * slope + baseBorderWidth;
    float borderMid = borderStart + borderWidthScaled / 2.0;
    float borderEnd = borderStart + borderWidthScaled;

    vec4 borderColorMix = mix(borderColorOuter, borderColorInner, smoothstep(borderMid - borderWidthScaled/4.0, borderMid + borderWidthScaled/4.0, distance_inv));
    vec4 bodyColorMix = mix(bodyColorOuter, bodyColorInner, (distance_inv - borderEnd) / (1.0 - borderEnd));

    if (u_BorderWidth < 0.01) {
        borderColorMix = outerShadow;
    }
    else if (u_BorderWidth > 9.99) {
        bodyColorMix = borderColorMix;
    }

    if (distance_inv <= borderStart - blend) {
        sliderTexture = outerShadow;
    }
    else if (distance_inv > borderStart-blend && distance_inv < borderStart+blend) {
        sliderTexture = mix(outerShadow, borderColorMix, (distance_inv - (borderStart - blend)) / (2.0 * blend));
    }
    else if (distance_inv > borderStart+blend && distance_inv <= borderEnd-blend) {
        sliderTexture = borderColorMix;
    }
    else if (distance_inv > borderEnd-blend && distance_inv < borderEnd+blend) {
        sliderTexture = mix(borderColorMix, bodyColorMix, (distance_inv - (borderEnd - blend)) / (2.0 * blend));
    }
    else if (distance_inv > borderEnd + blend) {
        sliderTexture = bodyColorMix;
    }

    return sliderTexture;
}
/*
void main() {
    float isTex0 = 1.0 - step(0.5, v_Texture);
    float isTex1 = step(0.5, v_Texture) * (1.0 - step(1.5, v_Texture));
    float isTex2 = step(1.5, v_Texture) * (1.0 - step(2.5, v_Texture));
    float isTex3 = step(2.5, v_Texture) * (1.0 - step(3.5, v_Texture));
    float isOther = step(3.5, v_Texture);

    vec4 color0 = texture2D(u_tex0, v_TexCoord);
    vec4 color1 = texture2D(u_tex1, v_TexCoord);
    vec4 color2 = texture2D(u_tex2, v_TexCoord);
    vec4 color3 = texture2D(u_tex3, v_TexCoord);
    vec4 otherColor = vec4(v_TexCoord.x, v_TexCoord.y, 0.0, 1.0);

    vec4 texColor = color0 * isTex0 +
    color1 * isTex1 +
    color2 * isTex2 +
    color3 * isTex3 +
    otherColor * isOther;

    if(v_Color.r > 9.0)
    {
        vec4 sliderGradient = sliderFast(texColor);
        sliderGradient.a *= v_Color.a;
        gl_FragColor = sliderGradient;
        return;
    }

    gl_FragColor = texColor * v_Color;
}
*/
void main() {

    vec4 texColor;
    //int texIndex = int(v_Texture);

    if (v_Texture == 0.0)
        texColor = texture2D(u_tex0, v_TexCoord);
    else if (v_Texture == 1.0)
        texColor = texture2D(u_tex1, v_TexCoord);
    else if (v_Texture == 2.0)
        texColor = texture2D(u_tex2, v_TexCoord);
    else if (v_Texture == 3.0)
        texColor = texture2D(u_tex3, v_TexCoord);
    else
        texColor = vec4(v_TexCoord.x, v_TexCoord.y, 0, 1.0);

    if(v_Color.r > 9.0)
    {
        vec4 sliderGradient = sliderFast(texColor, v_TexCoord);
        //sliderGradient.a *= v_Color.a;
        gl_FragColor=sliderGradient;
        return;
    }

    gl_FragColor = texColor * v_Color;
}