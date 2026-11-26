#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_radius;
uniform float u_band;
uniform float u_strength;
uniform sampler2D u_texture_input;

out vec4 frag_color;

void main() {
  vec2 coordinate = FlutterFragCoord().xy;
  vec2 uv = coordinate / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec2 halfSize = u_size * 0.5;
  vec2 p = coordinate - halfSize;
  vec2 inner = halfSize - vec2(u_radius);
  vec2 q = abs(p) - inner;
  // Signed distance to the rounded box; the min() term keeps it growing inside the
  // straight part of the card, so only the rim band refracts, not the whole interior.
  float roundedEdge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - u_radius;
  float distanceIn = -roundedEdge;
  float edge = 1.0 - smoothstep(0.0, u_band, distanceIn);
  vec2 normal = p - clamp(p, -inner, inner);
  float normalLength = length(normal);
  if (normalLength < 0.001) normal = normalize(p + vec2(0.001));
  else normal /= normalLength;

  vec2 sampleUv = clamp((coordinate - normal * edge * u_band * u_strength) / u_size, 0.0, 1.0);
  frag_color = texture(u_texture_input, sampleUv);
}
