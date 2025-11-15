// shaders/bloom.frag
precision mediump float;
uniform sampler2D u_texture;
uniform vec2 u_resolution;
uniform float u_strength;

varying vec2 v_tex_coord;

void main() {
  vec2 uv = v_tex_coord;
  vec4 c = texture2D(u_texture, uv);
  vec4 bloom = vec4(0.0);
  float offset = 1.0 / 128.0;
  bloom += texture2D(u_texture, uv + vec2(0.0, offset)) * 0.3;
  bloom += texture2D(u_texture, uv - vec2(0.0, offset)) * 0.3;
  bloom += texture2D(u_texture, uv + vec2(offset, 0.0)) * 0.2;
  bloom += texture2D(u_texture, uv - vec2(offset, 0.0)) * 0.2;
  vec4 outCol = c + bloom * u_strength;
  outCol.rgb = outCol.rgb / (outCol.rgb + vec3(1.0));
  outCol.rgb = mix(outCol.rgb, pow(outCol.rgb, vec3(0.95)), 0.08);
  gl_FragColor = vec4(outCol.rgb, c.a);
}
