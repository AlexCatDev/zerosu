attribute vec3 a_Position;

uniform mat4 u_Projection;

void main() {
	vec4 projected = vec4(a_Position, 1.0) * u_Projection;
	gl_Position = projected;
}
