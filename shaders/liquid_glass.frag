#version 460 core
#include <flutter/runtime_effect.glsl>

// Flutter supplies these two uniforms when used as an ImageFilter.
uniform vec2 uTextureSize;
uniform sampler2D uBackdrop;
uniform vec2 uPanelSize;
// TL, TR, BR, BL radii, in logical pixels.
uniform vec4 uRadii;
uniform float uRefraction;
uniform float uDispersion;

out vec4 fragColor;

float roundedDistance(vec2 p) {
  float radius = p.x < 0.0
      ? (p.y < 0.0 ? uRadii.x : uRadii.w)
      : (p.y < 0.0 ? uRadii.y : uRadii.z);
  vec2 q = abs(p) - uPanelSize * 0.5 + radius;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

vec4 sampleBackdrop(vec2 uv) {
  // Prevent seams at the texture boundary and account for the GLES orientation.
  vec2 inset = 0.5 / uTextureSize;
  uv = clamp(uv, inset, vec2(1.0) - inset);
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uBackdrop, uv);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uTextureSize;
  vec2 p = (uv - 0.5) * uPanelSize;
  float distance = roundedDistance(p);
  // A rounded rim rather than a whole-panel magnification: the center stays clean.
  float rimWidth = clamp(min(uPanelSize.x, uPanelSize.y) * 0.18, 3.0, 22.0);
  float rim = 1.0 - smoothstep(0.0, rimWidth, max(-distance, 0.0));
  vec2 normal = vec2(
    roundedDistance(p + vec2(0.5, 0.0)) - roundedDistance(p - vec2(0.5, 0.0)),
    roundedDistance(p + vec2(0.0, 0.5)) - roundedDistance(p - vec2(0.0, 0.5))
  );
  normal /= max(length(normal), 0.0001);
  float bend = rim * rimWidth * 0.48 * uRefraction;
  vec2 refracted = uv - normal * bend / uPanelSize;
  vec2 split = normal * rim * uDispersion * min(2.5, rimWidth * 0.15) / uPanelSize;
  vec4 center = sampleBackdrop(refracted);
  vec4 red = sampleBackdrop(refracted + split);
  vec4 blue = sampleBackdrop(refracted - split);
  // Preserve premultiplied alpha, including on transparent backdrops.
  vec3 rgb = vec3(red.r, center.g, blue.b);
  rgb = min(rgb, vec3(center.a));
  fragColor = vec4(rgb, center.a);
}
