precision mediump float;

varying vec2 v_TexCoord;
varying vec4 v_Color;
varying float v_Texture;

uniform sampler2D u_tex0;
uniform sampler2D u_tex1;
uniform sampler2D u_tex2;
uniform sampler2D u_tex3;

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

    gl_FragColor = texColor * v_Color;
}
