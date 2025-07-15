attribute vec2 a_Pos;
attribute vec2 a_TexCoord;
attribute vec4 a_Color;
attribute float a_Texture;

uniform mat4 u_Projection;

varying vec2 v_TexCoord;
varying vec4 v_Color;
varying float v_Texture;

void main() {
    gl_Position = vec4(a_Pos, 0.0, 1.0) * u_Projection;

    v_TexCoord = a_TexCoord;
    v_Color = a_Color;
    v_Texture = a_Texture;
}